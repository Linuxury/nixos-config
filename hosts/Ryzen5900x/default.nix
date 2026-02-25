# ===========================================================================
# hosts/Ryzen5900x/default.nix — AMD Ryzen 9 5900x Desktop
#
# Owner: linuxury
# Hardware: AMD Ryzen 9 5900x, AMD Radeon RX 7900 XTX
# Type: Desktop — no encryption, full performance
# Role: Personal daily driver desktop
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
    # No nixos-hardware profile needed for a custom desktop build —
    # generic AMD support is handled by our drivers module perfectly fine.
    # -------------------------------------------------------------------------
    ../../modules/base/common.nix
    ../../modules/base/linuxury-ssh.nix
    ../../modules/hardware/drivers.nix
    ../../modules/desktop-environments/cosmic.nix
    #../../modules/desktop-environments/hyprland.nix
    #../../modules/desktop-environments/niri.nix
    ../../modules/gaming/gaming.nix
    ../../modules/development/development.nix
    ../../modules/base/firefox.nix
    ../../modules/base/auto-update.nix
  ];

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Ryzen5900x";

  # =========================================================================
  # GPU driver selection
  # =========================================================================
  hardware.gpu = "amd";

  # =========================================================================
  # Filesystem — BTRFS with subvolumes
  #
  # Desktop has no LUKS — BTRFS sits directly on the partition.
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
  # Kernel — latest stable, swap to testing when ready
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # =========================================================================
  # AMD Radeon RX 7900 XTX specific settings
  #
  # The 7900 XTX is an RDNA3 card. These settings unlock its full
  # potential on Linux.
  # =========================================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff" # Unlocks all power management features
                                       # Required for full fan curve and
                                       # overclock control via corectrl
  ];

  # =========================================================================
  # CoreCtrl — GPU and CPU control
  #
  # CoreCtrl gives you a GUI to manage AMD GPU power profiles,
  # fan curves, and CPU frequency scaling. Think of it as the
  # Linux equivalent of AMD's own Adrenalin software.
  #
  # The polkit rule below lets you use CoreCtrl without needing
  # to enter your password every time it applies settings.
  # =========================================================================
  programs.corectrl = {
    enable = true;
    gpuOverclock.enable = true; # Allows GPU overclock controls in CoreCtrl
  };

  # =========================================================================
  # Multi-monitor support
  #
  # arandr gives a GUI for arranging monitors.
  # autorandr remembers and restores monitor layouts automatically.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    arandr       # GUI monitor arrangement tool
    autorandr    # Automatic monitor layout switching
    # corectrl is installed by programs.corectrl.enable above
  ];

  # =========================================================================
  # User account
  # =========================================================================
  users.users.linuxury = {
    isNormalUser = true;
    description  = "Linuxury";
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

  # =========================================================================
  # Tailscale — system daemon required for Home Manager's tailscale service
  # After first boot: sudo tailscale up
  # =========================================================================
  services.tailscale.enable = true;

  programs.fish.enable = true;
}
