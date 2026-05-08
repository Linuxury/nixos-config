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
#   - KDE (default DE)
#   - COSMIC (disabled)
#   - Gaming
#
# No development tools — kept clean and simple.
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

let
  # Logical CPU count (threads) on this machine.
  # Used to cap parallel Nix builds — each large package (LLVM, chromium, etc.)
  # can consume 4-8 GB RAM per job, so unconstrained builds cause OOM crashes.
  numThreads = 16; # Ryzen 7 5800x: 8 cores / 16 threads

  # Allow at most 1/4 of threads as parallel Nix build jobs.
  # 16 / 4 = 4 — enough throughput while leaving RAM headroom.
  nixBuildJobs = builtins.div numThreads 4;
in

{
  imports = [
    ../../modules/base/common.nix
    ../../modules/base/graphical-base.nix
    ../../modules/hardware/drivers.nix
    #../../modules/desktop-environments/cosmic.nix
    ../../modules/desktop-environments/kde.nix
    ../../modules/gaming/gaming.nix
    ../../modules/base/auto-update.nix
    ../../modules/base/babylinux-ssh.nix        # babylinux — primary SSH access
    ../../modules/base/linuxury-ssh.nix         # linuxury  — emergency SSH only
    ../../modules/base/babylinux-description.nix
    ../../modules/users/babylinux-packages.nix
    #../../modules/base/libreoffice.nix
    ../../modules/base/syncthing-babylinux.nix
  ];

  # =========================================================================
  # Nix build limits
  # =========================================================================
  nix.settings.max-jobs = nixBuildJobs;

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Ryzen5800x";

  # =========================================================================
  # GPU driver selection
  # =========================================================================
  hardware.gpu = "amd";

  services.nixos-auto-update.primaryUser = "babylinux";

  services.displayManager.defaultSession = "plasma";

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

    # -----------------------------------------------------------------------
    # Media-Server Samba share
    # Automounts on first access, disconnects after 60s idle.
    # nofail: non-fatal if the server is offline.
    # -----------------------------------------------------------------------
    "/mnt/Media-Server" = {
      device  = "//10.0.0.3/Media-Server";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=babylinux" "gid=users"
        "nofail" "_netdev" "noauto"
        "x-systemd.automount" "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

    "/mnt/MinisForum" = {
      device  = "//10.0.0.7/GameServers";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=babylinux" "gid=users"
        "nofail" "_netdev" "noauto"
        "x-systemd.automount" "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

    "/mnt/Torrents" = {
      device  = "//10.0.0.3/Downloads";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=babylinux" "gid=users"
        "nofail" "_netdev" "noauto"
        "x-systemd.automount" "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

  };

  # =========================================================================
  # Mount point directory + CIFS tools
  # =========================================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 babylinux users -"
    "d /mnt/MinisForum   0755 babylinux users -"
    "d /mnt/Torrents     0755 babylinux users -"
  ];

  # =========================================================================
  # Agenix secrets
  # =========================================================================
  age.secrets.smb-credentials = {
    file  = ../../secrets/smb-credentials.age;
    mode  = "0400";
    owner = "root";
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
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

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
  # OpenRGB — RGB lighting control
  #
  # Controls RGB LEDs on the motherboard, RAM, and peripherals.
  # The NixOS module installs the udev rules so OpenRGB can access
  # USB and SMBus controllers without root.
  # =========================================================================
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd"; # Loads the i2c-piix4 SMBus driver for AMD motherboards
  };

  # =========================================================================
  # Stability focused extras
  #
  # Since this is a machine you manage for someone else, we add a few
  # quality of life things that make it easier to support remotely.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    cifs-utils

    # Remote support
    rustdesk          # Open source remote desktop — lets you help her
                      # remotely without needing to be physically present

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
  # User account
  # =========================================================================
  users.users.babylinux = {
    isNormalUser = true;
    extraGroups  = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "gamemode"
    ];
    shell = pkgs.zsh;
  };

  # linuxury user — emergency SSH access only, no home on this host
  users.users.linuxury = {
    isNormalUser = true;
    home         = "/var/empty";
    createHome   = false;
    group        = "users";
    shell        = pkgs.bash;
  };

  # Hide linuxury from the login screen — emergency account only
  services.displayManager.hiddenUsers = [ "linuxury" ];

  programs.zsh.enable = true;
}
