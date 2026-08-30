# ===========================================================================
# hosts/Radxa-X4/default.nix — Radxa X4
#
# Owner: managed by linuxury
# Hardware: Intel N100, Intel UHD integrated graphics
# Type: Headless server — no DE, no display manager
# Role: Dedicated torrent host behind WireGuard VPN
#        - WireGuard (VPN for torrenting) bound to WiFi interface
#        - Tailscale (management) bound to Ethernet interface
#        - qBittorrent runs inside a VPN network namespace (killswitch)
#
# Enabled modules:
#   - Intel drivers
#   - system/core/default.nix
#   - services/samba/default.nix (shares for completed/incomplete torrents)
#
# FreshRSS was migrated to Media-Server — see hosts/Media-Server/freshrss.nix
# Data migration steps documented in that file.
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  imports = [
    # ==============================================================
    # System
    #   core         — locale, fonts, nix daemon, base CLI, boot defaults
    #   server-shell — headless zsh, aliases, zoxide/fzf/direnv
    # ==============================================================
    ../../modules/system/core/default.nix
    ../../modules/system/server-shell/default.nix

    # ==============================================================
    # Hardware
    #   drivers — Intel N100 UHD iGPU + basic support
    # ==============================================================
    ../../modules/hardware/drivers/default.nix

    # ==============================================================
    # Development — AI Tools
    #   ai-tools  — base: nix-ld, uv, ffmpeg (import alongside tools below)
    #   claude    — Claude Code CLI
    #   opencode  — OpenCode CLI
    #   local-llm — Ollama + GPU acceleration
    #   odysseus  — self-hosted AI workspace
    # ==============================================================
    ../../modules/development/ai-tools/default.nix
    ../../modules/development/ai-tools/claude/default.nix
    #../../modules/development/ai-tools/opencode/default.nix
    #../../modules/development/ai-tools/local-llm/default.nix
    #../../modules/development/ai-tools/odysseus/default.nix

    # ==============================================================
    # Development — Editors (headless — no GUI editors)
    # ==============================================================
    #../../modules/development/editors/neovim/default.nix
    #../../modules/development/editors/vscodium/default.nix
    #../../modules/development/editors/zed/default.nix

    # ==============================================================
    # Development — Languages
    #   python — python3, poetry, ruff, httpie
    #   rust   — rustup toolchain, cargo tools, just
    # ==============================================================
    #../../modules/development/languages/python/default.nix
    #../../modules/development/languages/rust/default.nix

    # ==============================================================
    # Services
    #   samba           — Torrents share at /data/torrents
    #   vpn-qbittorrent — WireGuard killswitch for qBittorrent (Mullvad)
    #   syncthing       — vault + nixos-config sync (linuxury pair)
    #   auto-update     — weekly nixos-rebuild from GitHub
    # ==============================================================
    ../../modules/services/samba/default.nix
    ../../modules/services/vpn-qbittorrent/default.nix
    ../../modules/services/syncthing/default.nix
    ../../modules/services/auto-update/default.nix
    #../../modules/services/ntfy/default.nix
    #../../modules/services/snapper/default.nix
    #../../modules/services/syncthing-babylinux/default.nix

    # ==============================================================
    # Users
    #   ssh — authorized keys for this host
    # ==============================================================
    ../../modules/users/linuxury/ssh/default.nix
  ];

  # ==============================================================
  # Host identity
  # ==============================================================
  networking.hostName = "Radxa-X4";

  # ==============================================================
  # Network interface configuration
  #
  # enp2s0 (Ethernet) — LAN only, static IP, no default gateway.
  #   Used by Samba, SSH, and Tailscale. Removed from NetworkManager so
  #   NM doesn't try to DHCP it or add a competing default route.
  #   Router also has a static DHCP lease for this MAC → always 10.0.0.5.
  #
  # wlp1s0 (WiFi) — internet-facing, managed by NetworkManager (DHCP).
  #   Provides the default route, which is what WireGuard uses for its
  #   VPN handshake traffic via the masquerade in vpn-qbittorrent.nix.
  # ==============================================================
  networking.networkmanager.unmanaged = [ "enp2s0" ];
  networking.interfaces.enp2s0 = {
    useDHCP = false;  # LAN only — no DHCP, no default route via Ethernet
    ipv4.addresses = [{ address = "10.0.0.5"; prefixLength = 24; }];
  };

  # Disable IPv6 — not needed and reduces attack surface / complexity.
  # networking.enableIPv6 sets net.ipv6.conf.all/default.disable_ipv6,
  # but NetworkManager re-enables IPv6 on interfaces it manages (wlp1s0).
  # The per-interface sysctl overrides NM after it brings the interface up.
  networking.enableIPv6 = false;
  boot.kernel.sysctl."net.ipv6.conf.wlp1s0.disable_ipv6" = 1;

  # ==============================================================
  # GPU driver selection
  # Intel UHD integrated graphics (Alder Lake N)
  # ==============================================================
  hardware.gpu = "intel";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # ==============================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on server
  # ==============================================================
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd:1" "noatime" ];
    };

    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd:1" "noatime" ];
    };

    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@nix" "compress=zstd:1" "noatime" ];
    };

    "/var/log" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@log" "compress=zstd:1" "noatime" ];
    };

    "/var/cache" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@cache" "compress=zstd:1" "noatime" ];
    };

    "/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@snapshots" "compress=zstd:1" "noatime" ];
    };

    "/swap" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@swap" "noatime" ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    # -----------------------------------------------------------------------
    # Media-Server Samba share — for Obsidian vault and shared files
    # Automounts on first access, disconnects after 60s idle.
    # -----------------------------------------------------------------------
    "/mnt/Media-Server" = {
      device = "//10.0.0.3/Media-Server";
      fsType = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=1002"   # linuxury — NOT 1000 on this host; UIDs vary per host by install-time declaration order (alex=1000, babylinux=1001, linuxury=1002 here)
        "gid=100"
        "nofail"
        "_netdev"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };
  };

  # ==============================================================
  # Swap
  # ==============================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];

  # ==============================================================
  # Kernel
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;           # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # ==============================================================
  # Intel N100 specific settings
  # ==============================================================
  boot.kernelParams = [
    "intel_pstate=active"
  ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;  # required for Intel WiFi firmware
  powerManagement.powertop.enable = true;

  # ==============================================================
  # GPIO — Radxa X4 specific
  # ==============================================================
  environment.systemPackages = with pkgs; [
    iotop
    nethogs
    ncdu
    smartmontools
    rsync
    rclone
    cifs-utils    # Required for CIFS/Samba mounts
    tmux
    lsof
    strace
    libgpiod
    i2c-tools
    minicom
  ];

  # ==============================================================
  # Disable audio — server doesn't need it
  # ==============================================================
  services.pipewire.enable = lib.mkForce false;

  # ==============================================================
  # Disable suspend/sleep
  # ==============================================================
  systemd.targets.sleep.enable        = false;
  systemd.targets.suspend.enable      = false;
  systemd.targets.hibernate.enable    = false;
  systemd.targets.hybrid-sleep.enable = false;

  services.logind.settings.Login = {
    HandleSuspendKey             = "ignore";
    HandleHibernateKey           = "ignore";
    HandleLidSwitch              = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    IdleAction                   = "ignore";
  };

  # Scheduled reboot (1x daily) — coarse backstop now that
  # wifi-watchdog (below) handles routine recovery; also covers
  # wifi-watchdog itself getting stuck. Persistent = true catches
  # up once if the machine was off at the scheduled time.
  systemd.services.daily-reboot = {
    description = "Scheduled reboot";
    serviceConfig = {
      Type       = "oneshot";
      ExecStart  = "/run/current-system/sw/bin/systemctl reboot";
    };
  };

  systemd.timers.daily-reboot = {
    description = "Reboot timer — 1x daily (06:00)";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "06:00";
      Persistent         = true;      # catch up if machine was off at scheduled time
      RandomizedDelaySec = "5min";    # jitter so services don't always restart at exact times
    };
  };

  # ==============================================================
  # Server network optimizations
  # ==============================================================
  boot.kernel.sysctl = {
    "net.core.rmem_max"           = 134217728;
    "net.core.wmem_max"           = 134217728;
    "net.ipv4.tcp_rmem"           = "4096 87380 134217728";
    "net.ipv4.tcp_wmem"           = "4096 65536 134217728";
    "net.core.netdev_max_backlog" = 5000;
    "fs.inotify.max_user_watches" = 524288;
  };

  # ==============================================================
  # Tailscale — management access via Ethernet
  # Auth key stored in agenix — no manual "tailscale up" or URL needed.
  # ==============================================================
  age.secrets.tailscale-auth-radxa = {
    file = ../../secrets/tailscale-auth-radxa.age;
    mode = "0400";
  };

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-radxa.path;
    extraSetFlags = [ "--ssh=false" ];
  };

  # Tailscale watchdog — restarts tailscaled if it loses connectivity
  # Runs every 5 minutes. Uses 'tailscale ping' to verify the tunnel is
  # actually working, not just that the daemon is running.
  systemd.services.tailscale-watchdog = {
    description = "Restart tailscaled if Tailscale connectivity is lost";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "tailscale-watchdog" ''
        if ! ${pkgs.tailscale}/bin/tailscale ping --timeout=10s --c=1 ${config.networking.hostName} &>/dev/null; then
          echo "Tailscale connectivity lost, restarting tailscaled..."
          systemctl restart tailscaled
        fi
      '';
    };
  };

  systemd.timers.tailscale-watchdog = {
    description = "Tailscale connectivity watchdog timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec  = "2min";
      OnUnitActiveSec = "5min";
      Unit = "tailscale-watchdog.service";
    };
  };

  # WiFi watchdog — reboots wlp1s0's NM connection (then the host)
  # if real internet is unreachable. Checks 1.1.1.1/8.8.8.8, not the
  # gateway directly: the gateway can silently drop direct pings from
  # wlp1s0 while routing/NAT still works fine (router-side ICMP
  # quirk, confirmed live 2026-08-29) — a gateway-only check
  # false-positives on that and reboots for no reason. nmcli, not raw
  # `ip link`, since wlp1s0 is NM-managed. Two attempts with backoff
  # before rebooting, so a brief upstream blip doesn't reboot the
  # host mid-torrent.
  systemd.services.wifi-watchdog = {
    description = "Recover wlp1s0 if it loses real internet connectivity";
    serviceConfig = {
      Type = "oneshot";
      # ~156s worst case (2 internet checks + 2 bounded reconnect
      # attempts + backoff) — default 90s TimeoutStartSec is too tight.
      TimeoutStartSec = "240s";
      ExecStart = pkgs.writeShellScript "wifi-watchdog" ''
        IFACE="wlp1s0"
        GATEWAY="10.0.0.100"
        EXT1="1.1.1.1"
        EXT2="8.8.8.8"
        NMCLI="${pkgs.networkmanager}/bin/nmcli"
        PING="${pkgs.iputils}/bin/ping"

        check_internet() {
          $PING -I "$IFACE" -c 3 -W 2 "$EXT1" &>/dev/null && return 0
          $PING -I "$IFACE" -c 3 -W 2 "$EXT2" &>/dev/null && return 0
          return 1
        }

        if check_internet; then
          exit 0
        fi

        echo "wifi-watchdog: $IFACE cannot reach $EXT1 or $EXT2, attempting recovery"
        if $PING -I "$IFACE" -c 1 -W 2 "$GATEWAY" &>/dev/null; then
          echo "wifi-watchdog: note — gateway $GATEWAY IS reachable, so this isn't a gateway-level failure"
        else
          echo "wifi-watchdog: gateway $GATEWAY also unreachable"
        fi
        $NMCLI device show "$IFACE" 2>&1 || true

        for attempt in 1 2; do
          echo "wifi-watchdog: attempt $attempt — reconnecting $IFACE via NetworkManager"
          timeout 15 $NMCLI device disconnect "$IFACE" &>/dev/null || true
          sleep 2
          timeout 20 $NMCLI device connect "$IFACE" &>/dev/null || true

          sleep 8
          if check_internet; then
            echo "wifi-watchdog: recovered on attempt $attempt"
            exit 0
          fi

          echo "wifi-watchdog: attempt $attempt did not recover connectivity"
          if [ "$attempt" -eq 1 ]; then
            sleep 30
          fi
        done

        echo "wifi-watchdog: still unreachable after 2 recovery attempts, rebooting"
        systemctl reboot
      '';
    };
  };

  systemd.timers.wifi-watchdog = {
    description = "WiFi connectivity watchdog timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "60s";
      Unit = "wifi-watchdog.service";
    };
  };

  # ==============================================================
  # qBittorrent with WireGuard killswitch
  #
  # Architecture:
  #   - Tailscale (management) runs on the host, prefers Ethernet
  #   - WireGuard VPN for torrents uses WiFi as its transport because
  #     WiFi is Radxa's internet-facing interface (default route)
  #   - qBittorrent runs inside the vpn-qbt network namespace
  #   - All torrent traffic exits via WireGuard — structural killswitch
  #
  # Web UI: http://Radxa-X4:8080  (LAN) or via Tailscale hostname:8080
  #
  # Setup steps:
  #   1. Export WireGuard config from VPN Unlimited app
  #      (already managed by agenix — decrypted to /etc/wireguard/vpnunlimited.conf)
  #   2. On first access, log in with a temporary password — modern qBittorrent
  #      no longer defaults to admin/adminadmin. It generates a random temp
  #      password on every service (re)start, logged only to journalctl:
  #        journalctl -u qbittorrent-vpn.service | grep "temporary password"
  #      Set a permanent one immediately (Options -> WebUI -> Change password)
  #      or it keeps randomizing on every restart/reboot.
  #   3. Set download paths to /data/torrents/incomplete and /data/torrents/complete
  #   4. Configure qBittorrent in Sonarr/Radarr as remote download client
  # ==============================================================
  age.secrets.wireguard-vpnunlimited = {
    file = ../../secrets/wireguard-vpnunlimited.age;
    path = "/etc/wireguard/vpnunlimited.conf";
    mode = "0600";
  };

  age.secrets.smb-credentials = {
    file = ../../secrets/smb-credentials.age;
    mode = "0400";
    owner = "root";
  };

  services.vpn-qbittorrent = {
    enable        = true;
    user          = "linuxury";
    watchedFolder = "/data/torrents/queued";

    # Failover servers — tried in order when the active tunnel goes down.
    # Primary (us-atl-wg-001) is in the agenix secret; these are the backups.
    # Public keys are the Mullvad server keys (not sensitive).
    failoverServers = [
      { name = "us-atl-wg-001"; publicKey = "nvyBkaEXHwyPBAm8spGB0TFzf2W5wPAl8EEuJ0t+bzs="; endpoint = "45.134.140.130:51820"; }
      { name = "us-dal-wg-001"; publicKey = "EAzbWMQXxJGsd8j2brhYerGB3t5cPOXqdIDFspDGSng="; endpoint = "146.70.211.66:51820"; }
      { name = "us-nyc-wg-301"; publicKey = "IzqkjVCdJYC1AShILfzebchTlKCqVCt/SMEXolaS3Uc="; endpoint = "143.244.47.65:51820"; }
      { name = "us-chi-wg-201"; publicKey = "+Xx2mJnoJ+JS11Z6g8mp6aUZV7p6DAN9ZTAzPaHakhM="; endpoint = "87.249.134.1:51820"; }
      { name = "us-lax-wg-001"; publicKey = "zqsfGglzJPY657WMRxf/S4omG7+ZkSDIpDq+ggbc9yo="; endpoint = "23.234.72.2:51820"; }
    ];
  };

  # Download directories — /data/ allows an NVMe to be mounted there later.
  # If no extra drive is attached, these live on the eMMC/main BTRFS pool.
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server                    0755 linuxury users -"
    "d /data                             0755 root     users -"
    "d /data/torrents                    0775 linuxury users -"
    "d /data/torrents/complete           0775 linuxury users -"
    "d /data/torrents/incomplete         0775 linuxury users -"
  ];

  # ==============================================================
  # Samba — share torrent directories for file management
  #
  # Access: \\Radxa-X4\Torrents
  # ==============================================================
  services.samba.settings = {
    # Bind Samba to Ethernet only — never listens on WiFi or the veth pair.
    # "bind interfaces only" prevents nmbd/smbd from accepting connections
    # on wlp1s0 (10.0.0.32) or veth-qbt (10.200.200.x).
    global = {
      "interfaces"           = "lo enp2s0";
      "bind interfaces only" = "yes";
    };

    "Torrents" = {
      path             = "/data/torrents";
      comment          = "Torrent downloads";
      browseable       = "yes";
      "read only"      = "no";
      "valid users"    = "linuxury babylinux";
      "create mask"    = "0664";
      "directory mask" = "0775";
    };
  };

  networking.firewall.allowedTCPPorts = [ 445 139 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];

  # ==============================================================
  # Users
  # ==============================================================
  users.users = {
    linuxury = {
      isNormalUser = true;
      extraGroups  = [ "wheel" "networkmanager" "gpio" ];
      shell        = pkgs.zsh;
    };

    babylinux = {
      isNormalUser = true;
      extraGroups  = [ "networkmanager" ];
      shell        = pkgs.zsh;
    };

    alex = {
      isNormalUser = true;
      extraGroups  = [];
      shell        = pkgs.zsh;
    };
  };
}
