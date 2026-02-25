# ===========================================================================
# hosts/Radxa-X4/default.nix — Radxa X4
#
# Owner: managed by linuxury
# Hardware: Intel N100, Intel UHD integrated graphics
# Type: Headless server — no DE, no display manager
# Role: Home server — services TBD
#
# Enabled modules:
#   - Intel drivers
#   - base/common.nix
#   - FreshRSS (port 8080)
#
# No desktop environment, no Home Manager, no gaming, no development.
# Managed remotely via SSH by linuxury.
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    ../../modules/base/common.nix
    ../../modules/base/linuxury-ssh.nix
    ../../modules/hardware/drivers.nix
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
  #
  # The Intel N100 is a newer Alder Lake N chip. Using latest stable
  # ensures we have the best driver support for this relatively recent SoC.
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # =========================================================================
  # Intel N100 specific settings
  #
  # The N100 is an efficiency-focused chip designed for low power
  # operation. These settings help it run optimally as a always-on
  # server without wasting power.
  # =========================================================================
  boot.kernelParams = [
    "intel_pstate=active"  # Use Intel's own CPU frequency scaling driver
                           # Better performance/power balance than generic
  ];

  # =========================================================================
  # Intel microcode and power management
  # =========================================================================
  hardware.cpu.intel.updateMicrocode = true;

  # powertop auto-tune — applies Intel's recommended power saving settings
  # automatically at boot. Great for an always-on low power server.
  powerManagement.powertop.enable = true;

  # =========================================================================
  # GPIO — Radxa X4 specific
  #
  # The Radxa X4 has a 40-pin GPIO header with an RP2040 co-processor.
  # These packages let you interact with GPIO pins if needed for
  # home automation or hardware projects later.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Monitoring (same as MinisForum)
    iotop
    nethogs
    ncdu
    smartmontools
    rsync
    rclone
    tmux
    lsof
    strace

    # GPIO tools for the 40-pin header
    gpiod           # GPIO control from command line
                    # Usage: gpioget, gpioset commands
    i2c-tools       # I2C bus utilities for sensors and peripherals
    minicom         # Serial terminal — useful for debugging UART devices
  ];

  # =========================================================================
  # Disable audio — server doesn't need it
  # =========================================================================
  services.pipewire.enable      = lib.mkForce false;
  sound.enable                  = lib.mkForce false;
  hardware.pulseaudio.enable    = lib.mkForce false;

  # =========================================================================
  # Disable suspend/sleep
  # =========================================================================
  systemd.targets.sleep.enable        = false;
  systemd.targets.suspend.enable      = false;
  systemd.targets.hibernate.enable    = false;
  systemd.targets.hybrid-sleep.enable = false;

  services.logind.extraConfig = ''
    HandleSuspendKey=ignore
    HandleHibernateKey=ignore
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    IdleAction=ignore
  '';

  # =========================================================================
  # Server network optimizations — same as MinisForum
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
  # FreshRSS — self-hosted RSS/Atom feed reader
  #
  # Web UI: http://Radxa-X4:8080
  #
  # The NixOS module automatically configures nginx as the web server.
  # We serve on port 8080 instead of 80 to keep port 80 free for anything
  # else that might land on this server later.
  #
  # The admin password is managed by agenix. Create the secret once:
  #   nix run nixpkgs#agenix -- -e secrets/freshrss-admin-password.age
  #   (Type the password, save, close)
  #
  # After first boot:
  #   1. Open http://Radxa-X4:8080 — setup wizard runs on first visit
  #   2. The admin account (linuxury) is pre-created from passwordFile
  #   3. Add feeds manually or import an OPML file
  #   4. FreshRSS supports the GReader API for mobile apps
  #      (compatible with: Reeder, FeedMe, Fluent Reader, etc.)
  # =========================================================================

  # agenix decrypts the password at activation and places it at this path
  age.secrets.freshrss-admin-password = {
    file  = ../../secrets/freshrss-admin-password.age;
    owner = "freshrss";
    mode  = "0400";
  };

  services.freshrss = {
    enable       = true;
    baseUrl      = "http://Radxa-X4:8080";
    defaultUser  = "linuxury";
    passwordFile = config.age.secrets.freshrss-admin-password.path;
    virtualHost  = "freshrss";
    # Database: SQLite is the default and perfectly adequate
    # for a single-user RSS reader. No extra database service needed.
  };

  # Override the nginx virtualHost to listen on port 8080 instead of 80.
  # The freshrss module sets everything else (root, PHP-FPM, locations).
  services.nginx.virtualHosts.freshrss = {
    listen = [{ addr = "0.0.0.0"; port = 8080; }];
  };

  # Open port 8080 for FreshRSS
  networking.firewall.allowedTCPPorts = [ 8080 ];

  # =========================================================================
  # Automatic updates — same as MinisForum
  # =========================================================================
  system.autoUpgrade = {
    enable      = true;
    flake        = "github:linuxury/nixos-config";
    flags        = [ "--update-input" "nixpkgs" ];
    dates        = "weekly";
    allowReboot  = false;
  };

  # =========================================================================
  # Users — same three family accounts for Samba
  # =========================================================================
  users.users = {
    linuxury = {
      isNormalUser = true;
      description  = "Linuxury";
      extraGroups  = [ "wheel" "networkmanager" "gpio" ];
      # gpio group added so linuxury can use GPIO pins without sudo
      shell        = pkgs.fish;
    };

    babylinux = {
      isNormalUser = true;
      description  = "BabyLinux";
      extraGroups  = [ "networkmanager" ];
      shell        = pkgs.fish;
    };

    alex = {
      isNormalUser = true;
      description  = "Alex";
      extraGroups  = [];
      shell        = pkgs.fish;
    };
  };

  programs.fish.enable = true;
}
