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

{ pkgs, ... }:

{
  imports = [
    # ==============================================================
    # System
    #   core     — locale, fonts, nix daemon, base CLI, boot defaults
    #   graphical — Wayland stack, PipeWire audio, XDG portals, base pkgs
    # ==============================================================
    ../../modules/system/core/default.nix
    ../../modules/system/graphical/default.nix

    # ==============================================================
    # Hardware
    #   drivers — GPU (AMD/NVIDIA/Intel) + OpenCL/VAAPI
    # ==============================================================
    ../../modules/hardware/drivers/default.nix

    # ==============================================================
    # Graphical Apps — all optional, comment out to remove
    #   firefox     — primary browser
    #   helium      — secondary browser (Firefox-based)
    #   libreoffice — office suite
    #   fluxer      — Discord client
    #   kdeconnect  — phone integration
    #   zen-browser — privacy-focused Firefox fork
    # ==============================================================
    ../../modules/system/graphical/firefox/default.nix
    ../../modules/system/graphical/helium/default.nix
    ../../modules/system/graphical/libreoffice/default.nix
    ../../modules/system/graphical/fluxer/default.nix
    ../../modules/services/kdeconnect/default.nix
    #../../modules/system/graphical/zen-browser/default.nix

    # ==============================================================
    # Desktop Environment — enable ONE (includes shell + greeter)
    # ==============================================================
    ../../modules/desktops/kde/default.nix
    #../../modules/desktops/cosmic/default.nix
    #../../modules/desktops/gnome/default.nix

    # ==============================================================
    # Compositor — enable ONE, pair with Shell + Greeter below
    # ==============================================================
    #../../modules/compositors/hyprland/default.nix
    #../../modules/compositors/mangowc/default.nix
    #../../modules/compositors/niri/default.nix

    # ==============================================================
    # Shell — enable ONE for the active compositor
    #   dms      — bundles its own greeter, skip Greeter section
    #   wayle    — needs greeters/sddm
    #   noctalia — needs greeters/sddm
    # ==============================================================
    #../../modules/shells/wayle/default.nix
    #../../modules/shells/dms/default.nix
    #../../modules/shells/noctalia/default.nix

    # ==============================================================
    # Greeter — skip if using dms or a full DE (they bundle their own)
    # ==============================================================
    #../../modules/greeters/sddm/default.nix

    # ==============================================================
    # Components — individual desktop components
    #   only needed with bare compositors not using a full shell
    # ==============================================================
    #../../modules/components/bar/waybar/default.nix
    #../../modules/components/launcher/wofi/default.nix
    #../../modules/components/notifications/swaync/default.nix

    # ==============================================================
    # Gaming
    #   Steam, Proton/Wine, Lutris, MangoHud, gamemode, controllers
    # ==============================================================
    ../../modules/gaming/default.nix

    # ==============================================================
    # Development — AI Tools (not a development host)
    #   ai-tools  — base: nix-ld, uv, ffmpeg (import alongside tools below)
    #   claude    — Claude Code CLI + VSCodium extension
    #   opencode  — OpenCode CLI + VSCodium extension
    #   local-llm — Ollama + AMD ROCm GPU acceleration
    #   lm-studio — GUI LLM runner (requires ai-tools)
    #   odysseus  — self-hosted AI workspace
    # ==============================================================
    #../../modules/development/ai-tools/default.nix
    #../../modules/development/ai-tools/claude/default.nix
    #../../modules/development/ai-tools/opencode/default.nix
    #../../modules/development/ai-tools/local-llm/default.nix
    #../../modules/development/ai-tools/lm-studio/default.nix
    #../../modules/development/ai-tools/odysseus/default.nix

    # ==============================================================
    # Development — Editors (not a development host)
    #   neovim   — full IDE: custom config, LSPs, opencode-nvim, claude wrapper
    #   vscodium — GUI editor: Catppuccin theme, Claude Code + OpenCode extensions
    #   zed      — fast Wayland-native editor (Rust), vim mode
    # ==============================================================
    #../../modules/development/editors/neovim/default.nix
    #../../modules/development/editors/vscodium/default.nix
    #../../modules/development/editors/zed/default.nix

    # ==============================================================
    # Development — Languages (not a development host)
    #   python — python3, poetry, ruff, httpie
    #   rust   — rustup toolchain, cargo tools, just
    # ==============================================================
    #../../modules/development/languages/python/default.nix
    #../../modules/development/languages/rust/default.nix

    # ==============================================================
    # Services
    #   auto-update         — weekly nixos-rebuild from GitHub
    #   syncthing-babylinux — vault + nixos-config sync (babylinux pair)
    #   snapper             — BTRFS automatic snapshots
    # ==============================================================
    ../../modules/services/auto-update/default.nix
    ../../modules/services/syncthing-babylinux/default.nix
    #../../modules/services/snapper/default.nix
    #../../modules/services/wallpaper-slideshow/default.nix
    #../../modules/services/samba/default.nix
    #../../modules/services/ntfy/default.nix
    #../../modules/services/vpn-qbittorrent/default.nix
    #../../modules/services/syncthing/default.nix

    # ==============================================================
    # Users
    #   ssh         — authorized keys for this host
    #   description — GECOS display name (agenix secret)
    #   packages    — per-user package set
    # ==============================================================
    ../../modules/users/babylinux/ssh/default.nix
    ../../modules/users/babylinux/description/default.nix
    ../../modules/users/babylinux/packages/default.nix
    ../../modules/users/linuxury/ssh/default.nix
  ];

  # ==============================================================
  # Host identity
  # ==============================================================
  networking.hostName = "Asus-A15";

  # ==============================================================
  # GPU driver selection
  # Nvidia hybrid triggers the PRIME offload setup in drivers.nix
  # ==============================================================
  # TODO: switch back to "nvidia-hybrid" once PCI bus IDs are filled in above
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # ==============================================================
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
  # ==============================================================
  # hardware.nvidia.prime = {
  #   amdgpuBusId = "PCI:FILL:IN"; # AMD iGPU — replace with actual ID
  #   nvidiaBusId = "PCI:FILL:IN"; # Nvidia dGPU — replace with actual ID
  # };
  # TODO: fill in PCI bus IDs from: lspci | grep -E "VGA|3D"

  services.nixos-auto-update.primaryUser = "babylinux";

  services.displayManager.defaultSession = "plasma";

  # ==============================================================
  # LUKS — Full disk encryption
  # ==============================================================
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-label/nixos-luks";
    allowDiscards = true;
  };

  # ==============================================================
  # Filesystem — BTRFS with subvolumes on top of LUKS
  # ==============================================================
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

  # ==============================================================
  # Mount point directory + CIFS tools
  # ==============================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 babylinux users -"
    "d /mnt/MinisForum   0755 babylinux users -"
    "d /mnt/Torrents     0755 babylinux users -"
  ];

  environment.systemPackages = with pkgs; [
    cifs-utils
  ];

  # ==============================================================
  # Agenix secrets
  # ==============================================================
  age.secrets.smb-credentials = {
    file  = ../../secrets/smb-credentials.age;
    mode  = "0400";
    owner = "root";
  };

  # ==============================================================
  # Swap
  # ==============================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];

  # ==============================================================
  # Kernel
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

  # ==============================================================
  # Asus TUF specific kernel modules
  #
  # asus-wmi and asus-nb-wmi handle Asus-specific hardware:
  #   - Keyboard backlight control
  #   - Fan boost modes
  #   - ROG/TUF hotkeys
  # ==============================================================
  boot.kernelModules = [ "asus-wmi" "asus-nb-wmi" ];

  # ==============================================================
  # asusctl — Asus laptop control daemon
  #
  # asusctl gives you control over Asus-specific features:
  #   - Battery charge limit (e.g. stop charging at 80%)
  #   - Fan curves and performance profiles
  #   - Keyboard backlight (if available)
  #
  # After first boot set battery limit with:
  #   asusctl -c 80
  # ==============================================================
  services.asusd.enable = true;

  # ==============================================================
  # Power management for hybrid laptop
  #
  # supergfxctl works alongside asusctl to manage GPU switching.
  # It handles powering down the Nvidia GPU when not in use which
  # is critical for battery life on hybrid graphics laptops.
  # ==============================================================
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

  # ==============================================================
  # Touchpad
  # ==============================================================
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

  # ==============================================================
  # Lid and power button behavior
  # ==============================================================
  services.logind.settings.Login = {
    HandleLidSwitch              = "suspend";   # Suspend on lid close
    HandleLidSwitchExternalPower = "suspend";   # Even on AC
    HandlePowerKey               = "suspend";
    IdleAction                   = "suspend";
    IdleActionSec                = "20min";
  };

  # ==============================================================
  # User account
  # ==============================================================
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
