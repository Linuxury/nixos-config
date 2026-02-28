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
#   - COSMIC (default DE)
#   - Hyprland (experimentation)
#   - Niri (experimentation)
#   - Gaming
#   - Development
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

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
    ../../modules/hardware/drivers.nix
    ../../modules/desktop-environments/cosmic.nix
    #../../modules/desktop-environments/hyprland.nix
    #../../modules/desktop-environments/niri.nix
    ../../modules/gaming/gaming.nix
    ../../modules/development/development.nix
    ../../modules/base/auto-update.nix
  ];

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
    allowDiscards = true;  # Enables TRIM on the SSD through LUKS
                           # Important for SSD longevity and performance
  };

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
      # No compression on swap — compressed swap causes issues
    };

    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
      # Restrictive permissions on /boot for security
    };
  };

  # =========================================================================
  # Swap
  # =========================================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];

  # =========================================================================
  # Kernel — RC Mainline with stable fallback
  #
  # linux-rc is the release candidate kernel — bleeding edge like you
  # prefer from Arch. It gets the latest hardware support and fixes.
  # The stable kernel stays available in the boot menu as a fallback
  # via systemd-boot generations.
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # NOTE: True RC/mainline kernel requires linuxPackages_testing or a
  # custom kernel. linuxPackages_latest gives you the latest stable which
  # is a safe starting point. When you're comfortable swap it for:
  #   pkgs.linuxPackages_testing  ← closest to RC mainline in nixpkgs

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
      CPU_SCALING_GOVERNOR_ON_AC  = "performance";  # Full speed on charger
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";    # Save battery on battery

      # AMD CPU power management
      CPU_ENERGY_PERF_POLICY_ON_AC  = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Keep battery between 20-80% to preserve long term health.
      # ThinkPads support this natively via the embedded controller.
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0  = 80;

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
      tapping          = true;   # Tap to click
      naturalScrolling = true;   # Reverse scroll direction (like macOS/modern default)
      scrollMethod     = "twofinger";
      middleEmulation  = true;   # Three finger tap = middle click
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
    login.fprintAuth   = true;
    sudo.fprintAuth    = true;
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
  # These modules improve hardware support on the T14s:
  # thinkpad_acpi — fan control, hotkeys, LED control
  # acpi_call     — required by TLP for battery threshold control
  # =========================================================================
  boot.kernelModules = [ "thinkpad_acpi" "acpi_call" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];

  # =========================================================================
  # Lid and power button behavior
  # =========================================================================
  services.logind = {
    lidSwitch              = "suspend";          # Suspend when lid closes
    lidSwitchExternalPower = "suspend";          # Even on AC — saves energy
    settings.Login = {
      HandlePowerKey = "suspend";
      IdleAction     = "suspend";
      IdleActionSec  = "20min";
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
    extraGroups  = [
      "wheel"          # sudo access
      "networkmanager" # manage network connections without sudo
      "video"          # access to video devices
      "audio"          # access to audio devices
      "input"          # access to input devices (controllers, etc)
      "gamemode"       # access to GameMode daemon
    ];
    shell = pkgs.fish; # We'll configure fish properly in home.nix
  };

  # =========================================================================
  # Tailscale — system daemon required for Home Manager's tailscale service
  # After first boot: sudo tailscale up
  # =========================================================================
  services.tailscale.enable = true;

  # =========================================================================
  # Fish — enable system-wide so it's available as a login shell
  # Actual configuration lives in users/linuxury/home.nix
  # =========================================================================
  programs.fish.enable = true;
}
