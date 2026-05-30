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
#   - KDE (default DE)
#   - COSMIC (disabled)
#   - Gaming
#
# Special considerations:
#   - Hybrid graphics requires PRIME offloading
#   - Asus battery management via asusctl
#   - PCI bus IDs must be filled in manually (see docs/)
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    # ── System ──────────────────────────────────────────────────────────────
    # core: locale, fonts, nix daemon, base CLI packages, boot defaults.
    # graphical: Wayland stack, PipeWire audio, XDG portals, graphical base pkgs.
    # nixos-hardware.nixosModules.asus-battery is passed via flake.nix extraModules
    # (battery charge threshold + ASUS power management for this laptop model).
    ../../modules/system/core/default.nix
    ../../modules/system/graphical/default.nix

    # ── Hardware ────────────────────────────────────────────────────────────
    # drivers: GPU (AMD/NVIDIA/Intel) + OpenCL/VAAPI. Selected via hardware.gpu option.
    # This host uses Nvidia hybrid (AMD iGPU + GTX 1660 Ti dGPU via PRIME offloading).
    # openrgb: RGB lighting control daemon (not applicable on this laptop).
    ../../modules/hardware/drivers/default.nix
    #../../modules/hardware/openrgb/default.nix

    # ── Desktop Environments ─────────────────────────────────────────────────
    # Full DEs — include their own shell and greeter. Enable ONE.
    ../../modules/desktops/kde/default.nix
    #../../modules/desktops/cosmic/default.nix
    #../../modules/desktops/gnome/default.nix

    # ── Wayland Compositors ──────────────────────────────────────────────────
    # Bare compositors — no shell or greeter included. Enable ONE.
    # Pair with a Shell and Greeter below.
    #../../modules/compositors/hyprland/default.nix
    #../../modules/compositors/mangowc/default.nix
    #../../modules/compositors/niri/default.nix

    # ── Shell Layer ──────────────────────────────────────────────────────────
    # Full DEs above already include a shell — no import needed here.
    # For Wayland compositors: import ONE shell.
    #   dms     — bundles its own greeter, no Greeters import needed
    #   wayle   — needs greeters/sddm
    #   noctalia — needs greeters/sddm

    # ── Greeters ─────────────────────────────────────────────────────────────
    # Full DEs above bundle their own greeter — no import needed here.
    # For Wayland compositors (non-DMS): import ONE greeter.
    #../../modules/greeters/sddm/default.nix

    # ── Gaming ──────────────────────────────────────────────────────────────
    # Steam, Proton/Wine, Lutris, MangoHud, gamemode, controller support.
    ../../modules/gaming/default.nix

    # ── Development ─────────────────────────────────────────────────────────
    # Neovim full IDE setup, language servers, dev toolchains, formatters.
    # Kept off — this machine is kept clean and simple.
    #../../modules/development/default.nix

    # ── Services ────────────────────────────────────────────────────────────
    # auto-update: weekly nixos-rebuild from GitHub + Obsidian update log.
    # syncthing-babylinux: Obsidian vault + nixos-config sync (babylinux pair).
    # ai-tools: Claude Code, AI integrations (disabled — insufficient RAM for local AI).
    # snapper: BTRFS automatic snapshots — timeline + pre/post around updates.
    # local-llm: Ollama local model runner (disabled — laptop RAM constraints).
    # wallpaper-slideshow: matugen wallpaper rotation — COSMIC/non-Hyprland only.
    # samba/ntfy/vpn-qbittorrent: server-side services, not for desktops.
    # syncthing: linuxury's sync pair (linuxury hosts only).
    ../../modules/services/auto-update/default.nix
    ../../modules/services/syncthing-babylinux/default.nix
    #../../modules/services/ai-tools/default.nix
    #../../modules/services/snapper/default.nix
    #../../modules/services/local-llm/default.nix
    #../../modules/services/wallpaper-slideshow/default.nix
    #../../modules/services/samba/default.nix
    #../../modules/services/ntfy/default.nix
    #../../modules/services/vpn-qbittorrent/default.nix
    #../../modules/services/syncthing/default.nix

    # ── Users ───────────────────────────────────────────────────────────────
    # babylinux: primary user — SSH, display name, packages.
    # linuxury: emergency SSH access only (no packages, no description).
    ../../modules/users/babylinux/ssh/default.nix
    ../../modules/users/babylinux/description/default.nix
    ../../modules/users/babylinux/packages/default.nix
    ../../modules/users/linuxury/ssh/default.nix
  ];

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

  services.nixos-auto-update.primaryUser = "babylinux";

  services.displayManager.defaultSession = "plasma";

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
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

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
