# ===========================================================================
# modules/services/vpn-qbittorrent.nix — qBittorrent with WireGuard Killswitch
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
#   1. Export WireGuard config from VPN Unlimited app
#        Tools → WireGuard → select server → Export Config
#   2. Save it to /etc/wireguard/vpnunlimited.conf  (wg-quick format)
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

  # Shorthand for the ip binary path (used heavily in scripts)
  ip  = "${pkgs.iproute2}/bin/ip";
  wg  = "${pkgs.wireguard-tools}/bin/wg";

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

    # Address = 10.x.x.x/32  — the IP assigned to our tunnel interface
    WG_ADDR=$(awk -F' *= *' '/^\[Interface\]/{f=1} f && /^Address/{print $2; exit}' "$WG_CONF")
    if [ -z "$WG_ADDR" ]; then
      echo "ERROR: Could not parse Address from $WG_CONF"
      exit 1
    fi

    # DNS = 1.1.1.1  — take the first address if comma-separated
    WG_DNS=$(awk -F' *= *' '/^\[Interface\]/{f=1} f && /^DNS/{print $2; exit}' "$WG_CONF" \
             | cut -d, -f1 | tr -d ' ')
    WG_DNS="${WG_DNS:-1.1.1.1}"

    # Endpoint = 1.2.3.4:51820  — we need just the IP part for routing
    WG_ENDPOINT_IP=$(awk -F' *= *' '/^\[Peer\]/{f=1} f && /^Endpoint/{print $2; exit}' "$WG_CONF" \
                     | cut -d: -f1)
    if [ -z "$WG_ENDPOINT_IP" ]; then
      echo "ERROR: Could not parse Endpoint from $WG_CONF"
      exit 1
    fi

    log "WireGuard address:  $WG_ADDR"
    log "VPN endpoint IP:    $WG_ENDPOINT_IP"
    log "DNS server:         $WG_DNS"

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

        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox"
                  + " --webui-port=${toString cfg.webUIPort}";

        Restart        = "on-failure";
        RestartSec     = "5s";
        TimeoutStopSec = "30s";
      };
    };
  };
}
