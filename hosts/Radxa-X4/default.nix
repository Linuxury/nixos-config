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
#   - base/common.nix
#   - samba.nix (shares for completed/incomplete torrents — see Item 3)
#
# FreshRSS was migrated to Media-Server — see hosts/Media-Server/freshrss.nix
# Data migration steps documented in that file.
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    ../../modules/base/common.nix
    ../../modules/base/linuxury-ssh.nix
    ../../modules/base/auto-update.nix
    ../../modules/base/server-shell.nix
    ../../modules/hardware/drivers.nix
    ../../modules/services/samba.nix
    ../../modules/services/vpn-qbittorrent.nix
    ../../modules/base/syncthing.nix
    ../../modules/base/ai-tools.nix
  ];

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Radxa-X4";

  # =========================================================================
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
  # =========================================================================
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

  # =========================================================================
  # GPU driver selection
  # Intel UHD integrated graphics (Alder Lake N)
  # =========================================================================
  hardware.gpu = "intel";

  # =========================================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on server
  # =========================================================================
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
        "uid=1000"
        "gid=100"
        "nofail"
        "_netdev"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };
  };

  # =========================================================================
  # Swap
  # =========================================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];

  # =========================================================================
  # Kernel
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # =========================================================================
  # Intel N100 specific settings
  # =========================================================================
  boot.kernelParams = [
    "intel_pstate=active"
  ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;  # required for Intel WiFi firmware
  powerManagement.powertop.enable = true;

  # =========================================================================
  # GPIO — Radxa X4 specific
  # =========================================================================
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

  # =========================================================================
  # Disable audio — server doesn't need it
  # =========================================================================
  services.pipewire.enable = lib.mkForce false;

  # =========================================================================
  # Disable suspend/sleep
  # =========================================================================
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

  # =========================================================================
  # Server network optimizations
  # =========================================================================
  boot.kernel.sysctl = {
    "net.core.rmem_max"           = 134217728;
    "net.core.wmem_max"           = 134217728;
    "net.ipv4.tcp_rmem"           = "4096 87380 134217728";
    "net.ipv4.tcp_wmem"           = "4096 65536 134217728";
    "net.core.netdev_max_backlog" = 5000;
    "fs.inotify.max_user_watches" = 524288;
  };

  # =========================================================================
  # Tailscale — management access via Ethernet
  # After first boot: sudo tailscale up
  # =========================================================================
  services.tailscale.enable = true;
  services.tailscale.extraUpFlags = [ "--advertise-tags=tag:ssh" ];

  # =========================================================================
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
  #   2. On first access change the default password: admin / adminadmin
  #   3. Set download paths to /data/torrents/incomplete and /data/torrents/complete
  #   4. Configure qBittorrent in Sonarr/Radarr as remote download client
  # =========================================================================
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
    enable = true;
    user   = "linuxury";
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

  # =========================================================================
  # Samba — share torrent directories for file management
  #
  # Access: \\Radxa-X4\Torrents
  # =========================================================================
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

  # =========================================================================
  # Users
  # =========================================================================
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
