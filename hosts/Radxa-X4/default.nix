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
  ];

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Radxa-X4";

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
  # Web UI: http://10.200.200.2:8080  (accessible on LAN via Tailscale)
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

  services.vpn-qbittorrent = {
    enable = true;
    user   = "linuxury";
  };

  # Download directories — /data/ allows an NVMe to be mounted there later.
  # If no extra drive is attached, these live on the eMMC/main BTRFS pool.
  systemd.tmpfiles.rules = [
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
      shell        = pkgs.fish;
    };

    babylinux = {
      isNormalUser = true;
      extraGroups  = [ "networkmanager" ];
      shell        = pkgs.fish;
    };

    alex = {
      isNormalUser = true;
      extraGroups  = [];
      shell        = pkgs.fish;
    };
  };

  programs.fish.enable = true;
}
