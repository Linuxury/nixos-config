# ===========================================================================
# hosts/Ryzen5800x/default.nix — AMD Ryzen 7 5800x Desktop
#
# Owner: babylinux
# Hardware: AMD Ryzen 7 5800x, AMD Radeon RX 5700 XT
# Type: Desktop — no encryption, stable and reliable
# Role: Wife's daily driver desktop
#
# Enabled modules:
#   - AMD drivers
#   - COSMIC (default DE)
#   - KDE (fallback, available at login screen)
#   - Gaming
#
# No development tools — kept clean and simple.
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    ../../modules/base/common.nix
    ../../modules/hardware/drivers.nix
    ../../modules/desktop-environments/cosmic.nix
    #../../modules/desktop-environments/kde.nix
    ../../modules/gaming/gaming.nix
    ../../modules/base/firefox.nix
    ../../modules/base/auto-update.nix
    ../../modules/services/vpn-qbittorrent.nix
  ];

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Ryzen5800x";

  # =========================================================================
  # GPU driver selection
  # =========================================================================
  hardware.gpu = "amd";

  # =========================================================================
  # Display manager session priority
  #
  # Both COSMIC and KDE are enabled so we need to explicitly tell NixOS
  # which session to use as default at the login screen.
  # COSMIC is the default — KDE is available as an option if she wants
  # to switch by clicking the session selector at login.
  # =========================================================================
  services.displayManager.defaultSession = "cosmic";

  # =========================================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on desktop
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
  # AMD Radeon RX 5700 XT specific settings
  #
  # The 5700 XT is an RDNA1 card. It has mature driver support on Linux
  # and works very reliably. CoreCtrl is available if she ever wants
  # GPU monitoring but we keep it optional here.
  # =========================================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  # =========================================================================
  # Stability focused extras
  #
  # Since this is a machine you manage for someone else, we add a few
  # quality of life things that make it easier to support remotely.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Remote support
    rustdesk          # Open source remote desktop — lets you help her
                      # remotely without needing to be physically present

    # Basic productivity
    libreoffice       # Full office suite (documents, spreadsheets etc)
    hunspell          # Spell checker used by LibreOffice
    hunspellDicts.en-us

    # Media
    vlc               # Reliable video player that plays anything
  ];

  # =========================================================================
  # Printing support
  #
  # CUPS handles printer management on Linux. Most modern printers
  # are detected automatically once this is enabled.
  # avahi enables network printer discovery.
  # =========================================================================
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint      # Supports a wide range of printers
      hplip           # HP printers specifically
    ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;  # Enables .local hostname resolution
    openFirewall = true;
  };

  # =========================================================================
  # VPN-scoped qBittorrent
  #
  # qBittorrent runs inside a WireGuard network namespace — all torrent
  # traffic is forced through VPN Unlimited. If the VPN drops, qBittorrent
  # loses network access completely (no leaks possible).
  #
  # Web UI: http://10.200.200.2:8080
  # Change default password (admin/adminadmin) immediately after first boot.
  #
  # The WireGuard config (including private key) is managed by agenix.
  # Create the secret once from your admin machine:
  #   nix run nixpkgs#agenix -- -e secrets/wireguard-vpnunlimited.age
  #   (Paste the full wg-quick config exported from VPN Unlimited app)
  # =========================================================================

  # agenix decrypts the WireGuard config at activation.
  # We write directly to the path vpn-qbittorrent.nix expects,
  # so the module works without any further changes.
  age.secrets.wireguard-vpnunlimited = {
    file = ../../secrets/wireguard-vpnunlimited.age;
    path = "/etc/wireguard/vpnunlimited.conf";
    mode = "0600";  # private key inside — must not be world-readable
  };

  services.vpn-qbittorrent = {
    enable = true;
    user   = "babylinux";
    # configFile defaults to /etc/wireguard/vpnunlimited.conf — matches above
  };

  # =========================================================================
  # User account
  # =========================================================================
  users.users.babylinux = {
    isNormalUser = true;
    description  = "BabyLinux";
    extraGroups  = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "gamemode"
    ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;
}
