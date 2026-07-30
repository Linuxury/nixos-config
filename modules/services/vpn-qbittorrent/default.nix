# ===========================================================================
# modules/services/vpn-qbittorrent/default.nix — qBittorrent with WireGuard Killswitch
#
# Runs qBittorrent-nox inside a dedicated WireGuard network namespace.
# All torrent traffic is forced through the VPN. If WireGuard drops for
# any reason, qBittorrent immediately loses all connectivity — no leaks.
#
# Architecture:
#
#   ┌─────────────────── HOST ───────────────────────────────────┐
#   │                                                            │
#   │   veth-qbt  ── 10.200.200.1/30                            │
#   │       │                                                    │
#   │       └──────── veth pair ──────────┐                     │
#   │                                     │                     │
#   │   ┌── NAMESPACE: vpn-qbt ───────────▼───────────────────┐ │
#   │   │   veth-qbt-ns   10.200.200.2/30                     │ │
#   │   │   wg-qbt        <VPN address from config>           │ │
#   │   │   lo            127.0.0.1                           │ │
#   │   │                                                     │ │
#   │   │   Route: <endpoint>/32  →  via 10.200.200.1         │ │
#   │   │   Route: default        →  wg-qbt   ← KILLSWITCH   │ │
#   │   │                                                     │ │
#   │   │   qbittorrent-nox  0.0.0.0:8080                    │ │
#   │   └─────────────────────────────────────────────────────┘ │
#   │                                                            │
#   └────────────────────────────────────────────────────────────┘
#
#   Web UI:  http://10.200.200.2:8080  (open in any browser on the desktop)
#   Default login: admin / adminadmin — change this immediately in Settings
#
# How the killswitch works:
#   qBittorrent's default route goes only through wg-qbt (WireGuard).
#   There is no fallback route through the physical network.
#   If the VPN tunnel goes down, the namespace has no usable default route
#   and qBittorrent cannot send or receive any data. Full stop.
#
# How the VPN endpoint is reached:
#   WireGuard needs to contact the VPN server to establish the tunnel.
#   We add a host-specific route for the endpoint IP via the veth pair,
#   so the initial handshake goes through the host's real internet connection.
#   Masquerade on the host rewrites the source IP for that traffic.
#
# Manual steps before first boot:
#   1. Export WireGuard config from Mullvad app or web dashboard
#        Account → WireGuard configuration → Generate key → Download config
#   2. Save it to /etc/wireguard/vpnunlimited.conf  (wg-quick format)
#        (file is still named vpnunlimited.conf for historical reasons)
#   3. chmod 600 /etc/wireguard/vpnunlimited.conf
#        (private key inside — must not be world-readable)
#
# To enable on a host, add to its imports and set:
#   services.vpn-qbittorrent.enable = true;
#   services.vpn-qbittorrent.user   = "babylinux";
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  cfg = config.services.vpn-qbittorrent;

  # Network namespace name
  ns = "vpn-qbt";

  # Interface names
  hostVeth = "veth-qbt";
  nsVeth   = "veth-qbt-ns";
  wgIface  = "wg-qbt";

  # Shorthand for binary paths (used heavily in scripts)
  ip   = "${pkgs.iproute2}/bin/ip";
  wg   = "${pkgs.wireguard-tools}/bin/wg";
  awk  = "${pkgs.gawk}/bin/awk";
  sed  = "${pkgs.gnused}/bin/sed";
  curl = "${pkgs.curl}/bin/curl";

  # ===========================================================================
  # netns-setup — creates the namespace, veth pair, and WireGuard tunnel
  # ===========================================================================
  netnsSetup = pkgs.writeShellScript "vpn-qbt-setup" ''
    set -euo pipefail

    WG_CONF="${cfg.configFile}"
    NS="${ns}"
    HOST_VETH="${hostVeth}"
    NS_VETH="${nsVeth}"
    WG_IFACE="${wgIface}"
    HOST_IP="${cfg.hostVethIP}"
    NS_IP="${cfg.nsVethIP}"

    log() { echo "[vpn-qbt] $*"; }

    # -----------------------------------------------------------------------
    # Validate that the WireGuard config file exists.
    # The private key lives in this file — it must be present before starting.
    # -----------------------------------------------------------------------
    if [ ! -f "$WG_CONF" ]; then
      echo "ERROR: WireGuard config not found at $WG_CONF"
      echo "Export your VPN Unlimited config (wg-quick format) and save it there."
      echo "Then: chmod 600 $WG_CONF"
      exit 1
    fi

    # -----------------------------------------------------------------------
    # Parse the wg-quick fields we need to apply manually.
    # wg-quick understands Address, DNS, Endpoint etc. but wg-setconf does not.
    # We parse them here and apply them as separate ip/wg commands.
    # -----------------------------------------------------------------------

    # Address = 10.x.x.x/32  — the IP assigned to our tunnel interface.
    # Mullvad dual-stack configs have "Address = IPv4,IPv6" — take only the
    # first (IPv4) entry; IPv6 is disabled on this host anyway.
    WG_ADDR=$(${awk} -F' *= *' '/^\[Interface\]/{f=1} f && /^Address/{print $2; exit}' "$WG_CONF" \
              | cut -d, -f1 | tr -d ' ')
    if [ -z "$WG_ADDR" ]; then
      echo "ERROR: Could not parse Address from $WG_CONF"
      exit 1
    fi

    # DNS = 1.1.1.1  — take the first address if comma-separated
    WG_DNS=$(${awk} -F' *= *' '/^\[Interface\]/{f=1} f && /^DNS/{print $2; exit}' "$WG_CONF" \
             | cut -d, -f1 | tr -d ' ')
    WG_DNS="''${WG_DNS:-1.1.1.1}"

    # Endpoint = 1.2.3.4:51820  — we need just the IP part for routing
    WG_ENDPOINT_IP=$(${awk} -F' *= *' '/^\[Peer\]/{f=1} f && /^Endpoint/{print $2; exit}' "$WG_CONF" \
                     | cut -d: -f1)
    if [ -z "$WG_ENDPOINT_IP" ]; then
      echo "ERROR: Could not parse Endpoint from $WG_CONF"
      exit 1
    fi

    log "WireGuard address:  $WG_ADDR"
    log "VPN endpoint IP:    $WG_ENDPOINT_IP"
    log "DNS server:         $WG_DNS"

    # -----------------------------------------------------------------------
    # Clean up any leftover state from a previous (failed) run.
    #
    # ExecStop only fires when the service is in 'active (exited)' state.
    # If the service previously failed, systemctl restart skips ExecStop,
    # leaving the namespace and veth pair behind. Clearing here makes
    # ExecStart idempotent — safe to run even if state already exists.
    # -----------------------------------------------------------------------
    ${ip} netns del "$NS"       2>/dev/null || true
    ${ip} link del "$HOST_VETH" 2>/dev/null || true
    rm -f "/etc/netns/$NS/resolv.conf"

    # -----------------------------------------------------------------------
    # Create the network namespace
    # -----------------------------------------------------------------------
    log "Creating network namespace: $NS"
    ${ip} netns add "$NS"

    # Enable loopback inside the namespace
    ${ip} netns exec "$NS" ${ip} link set lo up

    # -----------------------------------------------------------------------
    # veth pair — connects the namespace to the host
    #
    # This serves two purposes:
    #   1. VPN endpoint traffic can leave the namespace via the host's
    #      real internet connection (host forwards + masquerades it)
    #   2. The qBittorrent web UI is reachable from the host at $NS_IP:8080
    # -----------------------------------------------------------------------
    log "Creating veth pair: $HOST_VETH <-> $NS_VETH"

    # Create the pair; one end lives on the host, the other moves into the namespace
    ${ip} link add "$HOST_VETH" type veth peer name "$NS_VETH"
    ${ip} link set "$NS_VETH" netns "$NS"

    # Configure the host side
    ${ip} addr add "$HOST_IP/30" dev "$HOST_VETH"
    ${ip} link set "$HOST_VETH" up

    # Configure the namespace side
    ${ip} netns exec "$NS" ${ip} addr add "$NS_IP/30" dev "$NS_VETH"
    ${ip} netns exec "$NS" ${ip} link set "$NS_VETH" up

    # -----------------------------------------------------------------------
    # DNS for the namespace
    #
    # When a process runs via 'ip netns exec <ns>', the kernel automatically
    # bind-mounts /etc/netns/<ns>/resolv.conf over /etc/resolv.conf.
    # This gives the namespace its own DNS without affecting the host.
    # -----------------------------------------------------------------------
    log "Configuring DNS: $WG_DNS"
    mkdir -p "/etc/netns/$NS"
    echo "nameserver $WG_DNS" > "/etc/netns/$NS/resolv.conf"

    # -----------------------------------------------------------------------
    # WireGuard interface inside the namespace
    #
    # We create the interface directly inside the namespace, then configure it
    # with wg setconf. wg setconf does not understand wg-quick fields (Address,
    # DNS, etc.) so we strip those lines first into a temporary file.
    # -----------------------------------------------------------------------
    log "Setting up WireGuard interface: $WG_IFACE"

    ${ip} -n "$NS" link add "$WG_IFACE" type wireguard

    # Strip wg-quick-only directives; wg setconf only speaks WireGuard protocol
    WG_SETCONF=$(mktemp)
    grep -v -E '^\s*(Address|DNS|MTU|Table|PreUp|PostUp|PreDown|PostDown|SaveConfig)\s*=' \
      "$WG_CONF" > "$WG_SETCONF"

    ${ip} netns exec "$NS" ${wg} setconf "$WG_IFACE" "$WG_SETCONF"
    rm -f "$WG_SETCONF"

    # Assign the VPN tunnel address and bring the interface up
    ${ip} netns exec "$NS" ${ip} addr add "$WG_ADDR" dev "$WG_IFACE"
    ${ip} netns exec "$NS" ${ip} link set "$WG_IFACE" mtu 1420
    ${ip} netns exec "$NS" ${ip} link set "$WG_IFACE" up

    # -----------------------------------------------------------------------
    # Routing inside the namespace
    #
    # ORDER MATTERS here.
    #
    # 1. First add a specific route to the VPN endpoint via the veth/host.
    #    Without this, WireGuard cannot send its initial handshake because
    #    the default route would try to go through a tunnel that isn't up yet.
    #
    # 2. Then set the default route through WireGuard.
    #    This is the killswitch: all other traffic must go through the VPN.
    #    If the tunnel fails, there is no fallback route and qBittorrent
    #    loses connectivity immediately.
    # -----------------------------------------------------------------------
    log "Configuring routes"

    # Route VPN handshake traffic to the host (which has real internet)
    ${ip} netns exec "$NS" ${ip} route add "$WG_ENDPOINT_IP/32" via "$HOST_IP"

    # Default route through WireGuard — the killswitch
    ${ip} netns exec "$NS" ${ip} route add default dev "$WG_IFACE"

    log "Namespace ready. qBittorrent web UI → http://$NS_IP:${toString cfg.webUIPort}"
  '';

  # ===========================================================================
  # netns-teardown — cleans up everything created by setup
  # ===========================================================================
  netnsTeardown = pkgs.writeShellScript "vpn-qbt-teardown" ''
    set -euo pipefail

    NS="${ns}"
    HOST_VETH="${hostVeth}"

    # Deleting the namespace removes all interfaces inside it (wg-qbt, veth-qbt-ns).
    # The host-side veth peer (veth-qbt) is removed automatically by the kernel
    # when its peer disappears, but we also force-delete it just in case.
    ${ip} netns del "$NS"        2>/dev/null || true
    ${ip} link del "$HOST_VETH"  2>/dev/null || true

    # Clean up the per-namespace DNS config
    rm -f "/etc/netns/$NS/resolv.conf"
    rmdir "/etc/netns/$NS"       2>/dev/null || true
  '';

  # ===========================================================================
  # failoverScript — checks VPN connectivity and rotates to the next server
  #
  # Runs every 5 minutes (via timer). If the tunnel is healthy it exits
  # immediately (one curl call, no side effects).
  #
  # When the tunnel is down it reads /etc/vpn-qbt-failover.txt, skips the
  # currently configured endpoint, then tries each server in order:
  #   1. Extracts the [Interface] block from the live config (private key etc.)
  #   2. Writes a new config with the candidate's [Peer] block
  #   3. Restarts vpn-qbt-netns (which cascades to qbittorrent-vpn)
  #   4. Polls for 30 s — stops on first success
  # ===========================================================================
  failoverScript = pkgs.writeShellScript "vpn-qbt-failover" ''
    set -euo pipefail

    CONF="${cfg.configFile}"
    SERVERS_FILE="/etc/vpn-qbt-failover.txt"
    NS="${ns}"

    log() { echo "[vpn-qbt-failover] $*"; }

    if [ ! -f "$SERVERS_FILE" ]; then
      log "No failover servers file — skipping"
      exit 0
    fi

    # Fast path: VPN is healthy, nothing to do
    if ${ip} netns exec "$NS" ${curl} -sf --max-time 5 -o /dev/null https://1.1.1.1 2>/dev/null; then
      exit 0
    fi

    log "VPN connectivity lost — starting failover"

    # Extract [Interface] block (everything before the first [Peer] line).
    # This preserves the private key, address and DNS without having to parse them.
    INTERFACE=$(${sed} '/^\[Peer\]/,$d' "$CONF")

    # Get the IP of the endpoint we're currently trying (to skip it)
    CURRENT_EP=$(${awk} -F' = ' '/^\[Peer\]/{f=1} f && /^Endpoint/{print $2; exit}' "$CONF" \
                 | cut -d: -f1)
    log "Current endpoint: $CURRENT_EP (unreachable)"

    tried=0
    while IFS='|' read -r name pubkey endpoint; do
      ep_ip=$(echo "$endpoint" | cut -d: -f1)

      if [ "$ep_ip" = "$CURRENT_EP" ]; then
        continue  # Already know this one is down
      fi

      tried=$((tried + 1))
      log "Trying $name ($endpoint)…"

      # Write new config — same Interface, swapped Peer
      printf '%s\n\n[Peer]\nPublicKey = %s\nAllowedIPs = 0.0.0.0/0,::0/0\nEndpoint = %s\n' \
        "$INTERFACE" "$pubkey" "$endpoint" > "$CONF"
      chmod 600 "$CONF"

      # Restart the namespace; qbittorrent-vpn follows via Requires/After
      systemctl restart vpn-qbt-netns

      # Poll up to 30 s for the tunnel to come up (WireGuard handshakes lazily)
      for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 3
        if ${ip} netns exec "$NS" ${curl} -sf --max-time 3 -o /dev/null https://1.1.1.1 2>/dev/null; then
          log "Failover successful — now using $name ($endpoint)"
          exit 0
        fi
      done

      log "$name also unreachable — trying next…"
    done < "$SERVERS_FILE"

    if [ "$tried" -eq 0 ]; then
      log "All servers in failover list match the current endpoint — no alternatives"
    else
      log "All $tried failover server(s) exhausted — VPN remains down"
    fi
    exit 1
  '';

in {

  # ===========================================================================
  # Options
  # ===========================================================================
  options.services.vpn-qbittorrent = {

    enable = lib.mkEnableOption "qBittorrent with WireGuard network namespace killswitch";

    user = lib.mkOption {
      type        = lib.types.str;
      description = "User account to run qBittorrent-nox as";
    };

    configFile = lib.mkOption {
      type        = lib.types.path;
      default     = "/etc/wireguard/vpnunlimited.conf";
      description = "WireGuard config file path (wg-quick format)";
    };

    webUIPort = lib.mkOption {
      type        = lib.types.port;
      default     = 8080;
      description = "Port for the qBittorrent web UI";
    };

    hostVethIP = lib.mkOption {
      type        = lib.types.str;
      default     = "10.200.200.1";
      description = "IP address of the host-side veth interface";
    };

    nsVethIP = lib.mkOption {
      type        = lib.types.str;
      default     = "10.200.200.2";
      description = "IP address of the namespace-side veth interface (web UI address)";
    };

    failoverServers = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name      = lib.mkOption { type = lib.types.str; description = "Human-readable server name (for logs)"; };
          publicKey = lib.mkOption { type = lib.types.str; description = "WireGuard server public key"; };
          endpoint  = lib.mkOption { type = lib.types.str; description = "Server endpoint as IP:port"; };
        };
      });
      default     = [];
      description = ''
        Ordered list of fallback WireGuard servers.  When the active tunnel
        loses connectivity the failover timer tries each entry in sequence
        until one works.  The private key is preserved from the live config
        file — only the [Peer] block is replaced.
      '';
    };
  };

  # ===========================================================================
  # Implementation
  # ===========================================================================
  config = lib.mkIf cfg.enable {

    # =========================================================================
    # Required packages
    # =========================================================================
    environment.systemPackages = with pkgs; [
      wireguard-tools   # wg, wg-quick — for inspecting the tunnel manually
      qbittorrent-nox   # Headless qBittorrent daemon with web UI
      socat             # Used by the web UI proxy service
    ];

    # =========================================================================
    # IP forwarding
    #
    # Required so the host can forward the WireGuard handshake traffic from
    # the namespace (arriving on veth-qbt) out through the real internet
    # connection. Without this the VPN tunnel can never be established.
    # =========================================================================
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    # =========================================================================
    # Masquerade
    #
    # Traffic leaving the namespace for the VPN server has source IP
    # 10.200.200.2 (the namespace-side veth). The internet won't route packets
    # back to a private 10.x.x.x address, so we masquerade (SNAT) it to the
    # host's real outbound IP as it leaves.
    # =========================================================================
    networking.firewall.extraCommands = ''
      iptables -t nat -A POSTROUTING -s ${cfg.nsVethIP}/32 \
        ! -d ${cfg.hostVethIP}/30 -j MASQUERADE 2>/dev/null || true
    '';

    networking.firewall.extraStopCommands = ''
      iptables -t nat -D POSTROUTING -s ${cfg.nsVethIP}/32 \
        ! -d ${cfg.hostVethIP}/30 -j MASQUERADE 2>/dev/null || true
    '';

    # =========================================================================
    # Service 1 — Network namespace + WireGuard
    #
    # Runs as root (no User= set). Creates the namespace, veth pair, WireGuard
    # interface, and routing table. Stays "active" (RemainAfterExit) so that
    # stopping this service also runs the teardown and cleans everything up.
    # =========================================================================
    systemd.services.vpn-qbt-netns = {
      description = "VPN network namespace for qBittorrent (WireGuard killswitch)";

      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];
      before   = [ "qbittorrent-vpn.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        ExecStart       = netnsSetup;
        ExecStop        = netnsTeardown;
      };
    };

    # =========================================================================
    # Service 2 — qBittorrent-nox inside the VPN namespace
    #
    # Runs as the configured user but with its network restricted to the
    # vpn-qbt namespace. The filesystem is NOT isolated — qBittorrent can
    # still read/write the user's home directory (Downloads, config, etc).
    #
    # Requires vpn-qbt-netns: if the namespace service stops (e.g. VPN config
    # problem), systemd will also stop this service immediately.
    # =========================================================================
    systemd.services.qbittorrent-vpn = {
      description = "qBittorrent daemon inside VPN namespace";

      after    = [ "vpn-qbt-netns.service" ];
      requires = [ "vpn-qbt-netns.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type  = "simple";
        User  = cfg.user;
        Group = "users";
        UMask = "0002";

        # THE KILLSWITCH
        # qBittorrent's entire network stack is confined to vpn-qbt.
        # The only default route inside that namespace goes through WireGuard.
        # No VPN → no route → no traffic. Leaks are structurally impossible.
        NetworkNamespacePath = "/run/netns/${ns}";

        # Wait for the WireGuard tunnel to complete its first handshake before
        # qBittorrent starts. WireGuard is lazy — it does not handshake until
        # the first packet is sent. Without this, qBittorrent's DNS queries fire
        # before the tunnel is alive, DHT bootstrap fails, and torrents get stuck
        # at "Downloading metadata" until manually restarted.
        #
        # This script runs inside vpn-qbt (NetworkNamespacePath applies to all
        # ExecStart* commands). It sends a test request through WireGuard to
        # trigger the handshake, retrying for up to 30 seconds, then starts
        # qBittorrent regardless so a dead VPN doesn't block the service forever.
        ExecStartPre = pkgs.writeShellScript "qbt-wait-for-vpn" ''
          for i in 1 2 3 4 5 6 7 8 9 10; do
            if ${pkgs.curl}/bin/curl -sf --max-time 3 -o /dev/null https://1.1.1.1; then
              exit 0
            fi
            sleep 3
          done
          exit 0
        '';

        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox"
                  + " --webui-port=${toString cfg.webUIPort}";

        Restart        = "on-failure";
        RestartSec     = "5s";
        TimeoutStopSec = "30s";
      };
    };

    # =========================================================================
    # Service 3 — Web UI proxy (host → namespace)
    #
    # The qBittorrent web UI binds inside the vpn-qbt namespace on
    # 10.200.200.2:8080. That address is not reachable from other machines
    # on the LAN or via Tailscale — it only exists locally on this host.
    #
    # socat listens on 0.0.0.0:webUIPort on the host's real network interfaces
    # and forwards each connection into the namespace. This makes the web UI
    # accessible at http://Radxa-X4:8080 from any machine on the network
    # without any SSH tunneling.
    #
    # The proxy is NOT inside the VPN namespace — it runs on the host — so
    # it does not bypass the killswitch. Only web UI traffic is proxied;
    # qBittorrent's torrent traffic still goes exclusively through WireGuard.
    # =========================================================================
    systemd.services.qbittorrent-vpn-proxy = {
      description = "Proxy qBittorrent web UI from host to VPN namespace";

      # partOf: if qbittorrent-vpn stops/restarts, proxy follows.
      # But proxy crashing does NOT propagate back to qbittorrent-vpn.
      # (requires would kill qbittorrent-vpn when socat exits — wrong)
      after  = [ "qbittorrent-vpn.service" ];
      partOf = [ "qbittorrent-vpn.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type       = "simple";
        ExecStart  = "${pkgs.socat}/bin/socat"
                   + " TCP-LISTEN:${toString cfg.webUIPort},fork,reuseaddr"
                   + " TCP:${cfg.nsVethIP}:${toString cfg.webUIPort}";
        Restart    = "on-failure";
        RestartSec = "5s";
      };
    };

    # Open the web UI port on the host firewall so LAN/Tailscale can reach it
    networking.firewall.allowedTCPPorts = [ cfg.webUIPort ];

    # =========================================================================
    # Failover server list (written at build time, read by failoverScript)
    #
    # Each line: name|publicKey|endpoint
    # The private key is NOT stored here — it stays in cfg.configFile (agenix).
    # =========================================================================
    environment.etc."vpn-qbt-failover.txt" = lib.mkIf (cfg.failoverServers != []) {
      text = lib.concatMapStrings
        (s: "${s.name}|${s.publicKey}|${s.endpoint}\n")
        cfg.failoverServers;
      mode = "0644";
    };

    # =========================================================================
    # Service 4 — VPN health-check and automatic server failover
    #
    # Runs as root (needs to write cfg.configFile and call systemctl).
    # Runs inside the HOST namespace — uses 'ip netns exec' to probe vpn-qbt.
    # =========================================================================
    systemd.services.vpn-qbt-failover = lib.mkIf (cfg.failoverServers != []) {
      description = "VPN connectivity check and automatic server failover";

      after    = [ "qbittorrent-vpn.service" ];
      requires = [ "vpn-qbt-netns.service" ];

      serviceConfig = {
        Type            = "oneshot";
        ExecStart       = failoverScript;
        TimeoutStartSec = "300s";   # worst case: 5 servers × 30 s each + restarts
      };
    };

    systemd.timers.vpn-qbt-failover = lib.mkIf (cfg.failoverServers != []) {
      description = "Periodic VPN connectivity check (every 5 minutes)";
      wantedBy    = [ "timers.target" ];

      timerConfig = {
        OnBootSec       = "2min";    # first check shortly after boot
        OnUnitActiveSec = "5min";    # then every 5 minutes
        Unit            = "vpn-qbt-failover.service";
      };
    };
  };
}
