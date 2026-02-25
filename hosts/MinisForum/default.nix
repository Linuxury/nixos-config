# ===========================================================================
# hosts/MinisForum/default.nix — MinisForum UN1250
#
# Owner: managed by linuxury
# Hardware: Intel Core i5-1250P, Intel Iris Xe integrated graphics
# Type: Headless server — no DE, no display manager
# Role: Home server — services TBD
#
# Enabled modules:
#   - Intel drivers
#   - base/common.nix only
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
  networking.hostName = "MinisForum";

  # =========================================================================
  # GPU driver selection
  # Intel Iris Xe integrated graphics
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
  # Kernel — latest stable
  # Servers benefit from stability over bleeding edge
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # =========================================================================
  # Server optimizations
  #
  # Servers have different performance priorities than desktops.
  # These tweaks favor throughput and stability over interactivity.
  # =========================================================================
  boot.kernel.sysctl = {
    # Network performance
    "net.core.rmem_max"          = 134217728;  # Increase receive buffer
    "net.core.wmem_max"          = 134217728;  # Increase send buffer
    "net.ipv4.tcp_rmem"          = "4096 87380 134217728";
    "net.ipv4.tcp_wmem"          = "4096 65536 134217728";
    "net.core.netdev_max_backlog" = 5000;       # Handle bursts of traffic

    # File system
    "fs.inotify.max_user_watches" = 524288;    # Needed by some services
                                               # that watch many files
  };

  # =========================================================================
  # Disable audio — servers don't need it
  # Overrides the PipeWire setup in common.nix
  # =========================================================================
  services.pipewire.enable = lib.mkForce false;
  sound.enable             = lib.mkForce false;
  hardware.pulseaudio.enable = lib.mkForce false;

  # =========================================================================
  # Disable suspend/sleep — servers must stay on
  #
  # A server that suspends is useless. These settings ensure the machine
  # never sleeps regardless of inactivity.
  # =========================================================================
  systemd.targets.sleep.enable      = false;
  systemd.targets.suspend.enable    = false;
  systemd.targets.hibernate.enable  = false;
  systemd.targets.hybrid-sleep.enable = false;

  services.logind.extraConfig = ''
    HandleSuspendKey=ignore
    HandleHibernateKey=ignore
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    IdleAction=ignore
  '';

  # =========================================================================
  # Automatic updates
  #
  # Servers benefit from staying up to date automatically, especially
  # for security patches. This runs a weekly upgrade and rebuild.
  #
  # allowReboot = false means it won't reboot automatically — you control
  # when the server reboots after an update via SSH.
  # =========================================================================
  system.autoUpgrade = {
    enable      = true;
    flake        = "github:linuxury/nixos-config"; # Update with your repo URL
    flags        = [ "--update-input" "nixpkgs" ];
    dates        = "weekly";
    allowReboot  = false;
  };

  # =========================================================================
  # Server packages
  #
  # Minimal set — only what you need to manage and monitor the server.
  # Services get their own packages when we configure them.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Monitoring
    htop          # Already in common.nix but worth noting
    iotop         # Monitor disk I/O per process
    nethogs       # Monitor network usage per process
    ncdu          # Disk usage analyzer — find what's eating space
    smartmontools # Monitor hard drive health (S.M.A.R.T.)

    # File management
    rsync         # Fast file sync and backup tool
    rclone        # Cloud storage sync (useful for backups)

    # Utilities
    tmux          # Terminal multiplexer — keep sessions alive over SSH
                  # If your SSH connection drops, tmux keeps things running
    lsof          # List open files — useful for debugging
    strace        # Trace system calls — useful for debugging services
  ];

  # =========================================================================
  # Samba users
  #
  # All three family users exist on servers for Samba share permissions.
  # These are system accounts only — no login shell, no home directory
  # needed beyond what Samba requires.
  #
  # Samba itself will be configured in a separate services module later.
  # =========================================================================
  users.users = {
    linuxury = {
      isNormalUser = true;
      description  = "Linuxury";
      extraGroups  = [ "wheel" "networkmanager" ];
      shell        = pkgs.fish;
    };

    babylinux = {
      isNormalUser  = true;
      description   = "BabyLinux";
      # No wheel — wife doesn't need server admin access
      extraGroups   = [ "networkmanager" ];
      shell         = pkgs.fish;
    };

    alex = {
      isNormalUser  = true;
      description   = "Alex";
      # No wheel — kid definitely doesn't need server access
      extraGroups   = [];
      shell         = pkgs.fish;
    };
  };

  programs.fish.enable = true;
}
