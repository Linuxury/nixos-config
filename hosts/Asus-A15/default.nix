# ===========================================================================
# hosts/Asus-A15/default.nix — Asus TUF Gaming A15 FA506IU
#
# Owner: babylinux
# Hardware: AMD Ryzen 7 4800H, Nvidia GTX 1660 Ti (hybrid graphics)
# Type: Laptop — LUKS encrypted, hybrid GPU, gaming focused
# Role: Wife's laptop
#
# Enabled modules:
#   - Nvidia hybrid drivers (AMD iGPU + Nvidia dGPU)
#   - COSMIC (default DE)
#   - KDE (fallback)
#   - Gaming
#
# Special considerations:
#   - Hybrid graphics requires PRIME offloading
#   - Asus battery management via asusctl
#   - PCI bus IDs must be filled in manually (see docs/)
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

let
  # Logical CPU count (threads) on this machine.
  # Used to cap parallel Nix builds — each large package (LLVM, chromium, etc.)
  # can consume 4-8 GB RAM per job, so unconstrained builds cause OOM crashes.
  numThreads = 16; # Ryzen 7 4800H: 8 cores / 16 threads

  # Allow at most 1/4 of threads as parallel Nix build jobs.
  # 16 / 4 = 4 — enough throughput while leaving RAM headroom.
  nixBuildJobs = builtins.div numThreads 4;
in

{
  imports = [
    # nixos-hardware.nixosModules.asus-battery is passed via flake.nix extraModules
    ../../modules/base/common.nix
    ../../modules/base/graphical-base.nix
    ../../modules/hardware/drivers.nix
    ../../modules/desktop-environments/cosmic.nix
    #../../modules/desktop-environments/kde.nix
    ../../modules/gaming/gaming.nix
    ../../modules/base/auto-update.nix
    ../../modules/base/linuxury-ssh.nix
    ../../modules/users/babylinux-packages.nix
    ../../modules/base/syncthing.nix
    ../../modules/base/ai-tools.nix
  ];

  # =========================================================================
  # Nix build limits
  # =========================================================================
  nix.settings.max-jobs = nixBuildJobs;

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Asus-A15";

  # =========================================================================
  # GPU driver selection
  # Nvidia hybrid triggers the PRIME offload setup in drivers.nix
  # =========================================================================
  # TODO: switch back to "nvidia-hybrid" once PCI bus IDs are filled in above
  hardware.gpu = "amd";

  # =========================================================================
  # PRIME PCI Bus IDs
  #
  # These values are placeholders — you MUST replace them with the
  # actual IDs from this specific machine.
  #
  # To find them, boot any Linux live USB on the Asus A15 and run:
  #   lspci | grep -E "VGA|3D"
  #
  # Example output:
  #   05:00.0 VGA compatible controller: Advanced Micro Devices [AMD/ATI] ...
  #   01:00.0 3D controller: NVIDIA Corporation TU116M [GeForce GTX 1660 Ti]
  #
  # Convert to Nix format: "05:00.0" becomes "PCI:5:0:0"
  # Then fill in below and remove this comment block.
  # This is tracked in docs/manual-steps.md
  # =========================================================================
  # hardware.nvidia.prime = {
  #   amdgpuBusId = "PCI:FILL:IN"; # AMD iGPU — replace with actual ID
  #   nvidiaBusId = "PCI:FILL:IN"; # Nvidia dGPU — replace with actual ID
  # };
  # TODO: fill in PCI bus IDs from: lspci | grep -E "VGA|3D"

  # =========================================================================
  # Display manager session priority
  # Same as wife's desktop — COSMIC default, KDE available at login
  # =========================================================================
  services.displayManager.defaultSession = "cosmic";

  # =========================================================================
  # LUKS — Full disk encryption
  # =========================================================================
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-label/nixos-luks";
    allowDiscards = true;
  };

  # =========================================================================
  # Filesystem — BTRFS with subvolumes on top of LUKS
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
    # nofail: non-fatal if the server is offline (common on laptop away from home).
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

  };

  # =========================================================================
  # Mount point directory + CIFS tools
  # =========================================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 babylinux users -"
    "d /mnt/MinisForum   0755 babylinux users -"
  ];

  environment.systemPackages = with pkgs; [
    cifs-utils
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
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # =========================================================================
  # Asus TUF specific kernel modules
  #
  # asus-wmi and asus-nb-wmi handle Asus-specific hardware:
  #   - Keyboard backlight control
  #   - Fan boost modes
  #   - ROG/TUF hotkeys
  # =========================================================================
  boot.kernelModules = [ "asus-wmi" "asus-nb-wmi" ];

  # =========================================================================
  # asusctl — Asus laptop control daemon
  #
  # asusctl gives you control over Asus-specific features:
  #   - Battery charge limit (e.g. stop charging at 80%)
  #   - Fan curves and performance profiles
  #   - Keyboard backlight (if available)
  #
  # After first boot set battery limit with:
  #   asusctl -c 80
  # =========================================================================
  services.asusd.enable = true;

  # =========================================================================
  # Power management for hybrid laptop
  #
  # supergfxctl works alongside asusctl to manage GPU switching.
  # It handles powering down the Nvidia GPU when not in use which
  # is critical for battery life on hybrid graphics laptops.
  # =========================================================================
  services.supergfxd.enable = true;

  # TLP for general power management
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC  = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC  = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      # Battery threshold — keeps battery healthy long term
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0  = 80;
      PCIE_ASPM_ON_BAT = "powersupersave";
    };
  };

  services.power-profiles-daemon.enable = false;

  # =========================================================================
  # Touchpad
  # =========================================================================
  services.libinput = {
    enable = true;
    touchpad = {
      tapping            = true;
      naturalScrolling   = true;
      scrollMethod       = "twofinger";
      middleEmulation    = true;
      disableWhileTyping = true;
    };
  };

  # =========================================================================
  # Lid and power button behavior
  # =========================================================================
  services.logind = {
    lidSwitch              = "suspend";   # Suspend on lid close
    lidSwitchExternalPower = "suspend";   # Even on AC
    settings.Login = {
      HandlePowerKey = "suspend";
      IdleAction     = "suspend";
      IdleActionSec  = "20min";
    };
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

  # linuxury user — needed for Syncthing (vault sync) and auto-update notifications
  users.users.linuxury = {
    isNormalUser = true;
    home         = "/home/linuxury";
    createHome   = true;
    group        = "users";
  };

  programs.zsh.enable = true;
}
