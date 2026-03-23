# ===========================================================================
# hosts/ThinkPad/default.nix — Lenovo ThinkPad T14s Gen 4 (AMD)
#
# Owner: linuxury
# Hardware: AMD Ryzen 7 PRO 7840U, Radeon 780M iGPU
# Type: Laptop — LUKS encrypted, power managed
# Role: Personal daily driver
#
# Enabled modules:
#   - AMD drivers
#   - Hyprland (active DE — SDDM + pixie-sddm)
#   - Niri (future — commented out)
#   - Gaming
#   - Development
# ===========================================================================

{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  # Logical CPU count (threads) on this machine.
  # Used to cap parallel Nix builds — each large package (LLVM, chromium, etc.)
  # can consume 4-8 GB RAM per job, so unconstrained builds cause OOM crashes.
  numThreads = 16; # Ryzen 7 PRO 7840U: 8 cores / 16 threads

  # Allow at most 1/4 of threads as parallel Nix build jobs.
  # 16 / 4 = 4 — enough throughput while leaving RAM headroom.
  nixBuildJobs = builtins.div numThreads 4;
in

{
  imports = [
    # -------------------------------------------------------------------------
    # nixos-hardware profile for ThinkPad T14s Gen 4 AMD
    # Handles thermal management, power quirks, and hardware enablement
    # automatically for this specific model.
    # -------------------------------------------------------------------------
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14s-amd-gen4

    # -------------------------------------------------------------------------
    # Our shared modules — each one we wrote is pulled in here
    # -------------------------------------------------------------------------
    ../../modules/base/common.nix
    ../../modules/base/graphical-base.nix
    ../../modules/base/linuxury-ssh.nix
    ../../modules/base/linuxury-description.nix
    ../../modules/hardware/drivers.nix
    #../../modules/desktop-environments/cosmic.nix
    ../../modules/desktop-environments/hyprland.nix
    #../../modules/desktop-environments/niri.nix
    ../../modules/gaming/gaming.nix
    #../../modules/development/development.nix
    ../../modules/base/auto-update.nix
    ../../modules/users/linuxury-packages.nix
    ../../modules/services/syncthing.nix
  ];

  # =========================================================================
  # Nix build limits
  # =========================================================================
  nix.settings.max-jobs = nixBuildJobs;

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "ThinkPad";

  # =========================================================================
  # GPU driver selection — tells drivers.nix which profile to use
  # =========================================================================
  hardware.gpu = "amd";

  # =========================================================================
  # LUKS — Full disk encryption
  #
  # The BTRFS partition sits inside a LUKS container.
  # You'll be prompted for this passphrase before the system boots.
  # The label "nixos-luks" refers to the raw encrypted partition.
  # After unlocking, it becomes available as /dev/mapper/cryptroot
  # which is where our BTRFS filesystem lives.
  # =========================================================================
  boot.initrd.luks.devices."cryptroot" = {
    # We reference by label so it works regardless of whether the drive
    # is nvme0n1, nvme1n1, or any other device name
    device = "/dev/disk/by-label/nixos-luks";
    allowDiscards = true;
    # Enables TRIM on the SSD through LUKS
    # Important for SSD longevity and performance
  };

  # Early KMS — load the AMD GPU driver inside initrd so Plymouth gets a real
  # framebuffer before the root filesystem is mounted. Without this, Plymouth
  # falls back to the VGA text console and the LUKS passphrase prompt appears
  # as a tiny line at the top of the screen instead of a centered graphical UI.
  boot.initrd.kernelModules = [ "amdgpu" ];

  # =========================================================================
  # Filesystem — BTRFS with subvolumes
  #
  # All subvolumes live on the LUKS container (cryptroot).
  # Labels reference what we set during installation.
  # =========================================================================
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@home"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@nix"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/var/log" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@log"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/var/cache" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@cache"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@snapshots"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/swap" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@swap"
        "noatime"
      ];
      # No compression on swap — compressed swap causes issues
    };

    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
      # Restrictive permissions on /boot for security
    };

    # -----------------------------------------------------------------------
    # Media-Server Samba share
    # Automounts on first access, disconnects after 60s idle.
    # nofail: non-fatal if the server is offline (e.g. away from home).
    # Mount manually with: sudo mount /mnt/Media-Server
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
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

    # -----------------------------------------------------------------------
    # MinisForum Samba share — game server file management
    # Automounts on first access, disconnects after 60s idle.
    # nofail: non-fatal if the server is offline (e.g. away from home).
    # Mount manually with: sudo mount /mnt/MinisForum
    # -----------------------------------------------------------------------
    "/mnt/MinisForum" = {
      device = "//10.0.0.7/GameServers";
      fsType = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=1000"
        "gid=100"
        "nofail"
        "_netdev"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

  };

  # =========================================================================
  # CIFS tools — required for Samba/SMB mounts
  # =========================================================================
  environment.systemPackages = with pkgs; [
    cifs-utils
  ];

  # =========================================================================
  # Mount point directory
  # =========================================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 linuxury users -"
    "d /mnt/MinisForum   0755 linuxury users -"
  ];

  # =========================================================================
  # Agenix secrets
  # =========================================================================
  age.secrets.smb-credentials = {
    file = ../../secrets/smb-credentials.age;
    mode = "0400";
    owner = "root";
  };

  age.secrets.openrouter-api-key = {
    file = ../../secrets/openrouter-api-key.age;
    mode = "0440";
    owner = "root";
    group = "users";
  };

  # =========================================================================
  # Swap
  # =========================================================================
  swapDevices = [
    {
      device = "/swap/swapfile";
    }
  ];

  # =========================================================================
  # Kernel — Zen
  #
  # Zen patches mainline with lower-latency preemption, scheduler tweaks,
  # and throughput optimizations — great for both gaming and day-to-day
  # desktop responsiveness on a laptop.
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

  # =========================================================================
  # Power management — critical for laptop battery life
  #
  # TLP is a comprehensive power management tool that automatically
  # applies optimized settings for battery vs AC power.
  # =========================================================================
  services.tlp = {
    enable = true;
    settings = {
      # CPU scaling governor
      CPU_SCALING_GOVERNOR_ON_AC = "performance"; # Full speed on charger
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave"; # Save battery on battery

      # AMD CPU power management
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Keep battery between 75-95% — charges whenever plugged in and below
      # 75%, stops at 95% so there's plenty of charge if you need to head out.
      # ThinkPads support this natively via the embedded controller.
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 95;

      # PCIe power management
      PCIE_ASPM_ON_BAT = "powersupersave";
    };
  };

  # Prevent TLP and power-profiles-daemon from conflicting
  services.power-profiles-daemon.enable = false;

  # =========================================================================
  # Touchpad — libinput
  #
  # libinput is the modern input driver for touchpads on Linux.
  # These settings give a comfortable laptop touchpad experience.
  # =========================================================================
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true; # Tap to click
      naturalScrolling = true; # Reverse scroll direction (like macOS/modern default)
      scrollMethod = "twofinger";
      middleEmulation = true; # Three finger tap = middle click
      disableWhileTyping = true; # Disable touchpad while typing to avoid accidental input
    };
  };

  # =========================================================================
  # Fingerprint reader — fprintd
  #
  # The T14s G4 has a fingerprint reader supported by fprintd.
  # After installation, enroll your finger with:
  #   fprintd-enroll
  #
  # Then you can use your fingerprint for:
  #   - sudo authentication
  #   - login screen authentication
  # =========================================================================
  services.fprintd.enable = true;

  # Allow PAM (authentication system) to use fingerprint as an auth method
  security.pam.services = {
    login.fprintAuth = true;
    sudo.fprintAuth = true;
    polkit-1.fprintAuth = true;
  };

  # =========================================================================
  # Firmware — required for WiFi (Qualcomm QCNFA765 / ath12k)
  #
  # Without linux-firmware, the ath12k driver loads but finds no firmware
  # files and refuses to bind — leaving the WiFi adapter invisible to the
  # system. enableRedistributableFirmware pulls in linux-firmware which
  # contains the WCN7850/ath12k blobs needed for this card.
  # =========================================================================
  hardware.enableRedistributableFirmware = true;

  # =========================================================================
  # Laptop specific kernel modules
  #
  # thinkpad_acpi — fan control, hotkeys, LED control, battery events
  #
  # NOTE: acpi_call was previously included for TLP battery thresholds,
  # but the T14s Gen 4 (2022+) exposes charge thresholds natively via sysfs
  # (NATACPI interface). TLP 1.4+ uses that automatically — no acpi_call
  # needed. Loading it caused ACPI method execution during TLP restarts
  # (e.g. on nixos-rebuild switch) which could freeze the system.
  # =========================================================================
  boot.kernelModules = [ "thinkpad_acpi" ];

  # =========================================================================
  # Lid and power button behavior
  # =========================================================================
  services.logind = {
    lidSwitch = "suspend"; # Suspend when lid closes
    lidSwitchExternalPower = "suspend"; # Even on AC — saves energy
    settings.Login = {
      HandlePowerKey = "suspend";
      IdleAction = "suspend";
      IdleActionSec = "20min";
    };
  };

  # =========================================================================
  # User account
  #
  # This defines your system user. The password is set separately
  # (never put passwords in config files — use passwd after first boot).
  # =========================================================================
  users.users.linuxury = {
    isNormalUser = true;
    extraGroups = [
      "wheel" # sudo access
      "networkmanager" # manage network connections without sudo
      "video" # access to video devices
      "audio" # access to audio devices
      "input" # access to input devices (controllers, etc)
      "gamemode" # access to GameMode daemon
    ];
    shell = pkgs.zsh;
  };

  # =========================================================================
  # Tailscale — system daemon required for Home Manager's tailscale service
  # After first boot: sudo tailscale up
  # =========================================================================
  services.tailscale.enable = true;

  # =========================================================================
  # Zsh — enable system-wide so it's available as a login shell
  # Actual configuration lives in users/linuxury/home.nix
  # =========================================================================
  programs.zsh.enable = true;
}
