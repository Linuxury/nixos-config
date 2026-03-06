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
    ../../modules/base/graphical-base.nix
    ../../modules/base/linuxury-ssh.nix
    ../../modules/base/linuxury-description.nix
    ../../modules/hardware/drivers.nix
    ../../modules/desktop-environments/cosmic.nix
    #../../modules/desktop-environments/hyprland.nix
    #../../modules/desktop-environments/niri.nix
    ../../modules/gaming/gaming.nix
    ../../modules/development/development.nix
    ../../modules/base/auto-update.nix
    ../../modules/services/local-llm.nix
    ../../modules/users/linuxury-packages.nix
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

    "/mnt/warehouse" = {
      device = "/dev/disk/by-label/warehouse";
      fsType = "ext4";
      options = [ "defaults" "nofail" "x-gvfs-show" ];
    };

    "/mnt/games" = {
      device = "/dev/disk/by-label/games";
      fsType = "ext4";
      options = [ "defaults" "nofail" "x-gvfs-show" ];
    };

    # -----------------------------------------------------------------------
    # Media-Server Samba shares (10.0.0.3)
    # Credentials decrypted by agenix to /run/agenix/smb-credentials
    # -----------------------------------------------------------------------
    "/mnt/media-server/media" = {
      device  = "//10.0.0.3/media";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=1000" "gid=100"
        "nofail" "_netdev" "auto"
        "x-gvfs-show"
      ];
    };

    "/mnt/media-server/shared" = {
      device  = "//10.0.0.3/shared";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=1000" "gid=100"
        "nofail" "_netdev" "auto"
        "x-gvfs-show"
      ];
    };

    "/mnt/media-server/downloads" = {
      device  = "//10.0.0.3/downloads";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=1000" "gid=100"
        "nofail" "_netdev" "auto"
        "x-gvfs-show"
      ];
    };
  };

  # =========================================================================
  # Drive ownership — ensure linuxury owns the ext4 drive roots so Steam
  # and other user apps can write to them (tmpfiles runs after local-fs.target)
  # =========================================================================
  systemd.tmpfiles.rules = [
    "d /mnt/warehouse 0755 linuxury users -"
    "d /mnt/games     0755 linuxury users -"
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
  # Kernel — Zen
  #
  # Zen patches mainline with lower-latency preemption, scheduler tweaks,
  # and throughput optimizations — ideal for a gaming desktop.
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_zen;

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
    cifs-utils   # Required for CIFS/Samba mounts
    # corectrl is installed by programs.corectrl.enable above
  ];

  # =========================================================================
  # User account
  # =========================================================================
  users.users.linuxury = {
    isNormalUser = true;
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

  # =========================================================================
  # Local LLM — on-demand Ollama with ROCm for the 7900 XTX
  # First-time setup: ollama pull qwen2.5:14b
  # Usage: llm (chat), llm-start / llm-stop (server control)
  # =========================================================================
  services.localLlm = {
    enable = true;
    user   = "linuxury";
    # model defaults to "qwen2.5:14b" — change to "qwen2.5:32b" for more power
  };

  programs.fish.enable = true;
}
