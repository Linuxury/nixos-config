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
    #   (openrgb / lemokey-keychron are option-gated — see Hardware toggles)
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
  networking.hostName = "Ryzen5800x";

  # ==============================================================
  # GPU driver selection
  # ==============================================================
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  hardware.openrgb.enable = true;
  hardware.lemokey-keychron.enable = false;

  services.nixos-auto-update.primaryUser = "babylinux";

  services.displayManager.defaultSession = "plasma";

  # ==============================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on desktop
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

    # -----------------------------------------------------------------------
    # Local NTFS HDD — former Windows drive, now used as storage
    # Uses the ntfs3 in-kernel driver (faster than FUSE ntfs-3g).
    # force: mounts even if Windows left the dirty/hibernation flag set.
    # -----------------------------------------------------------------------
    "/mnt/Warehouse" = {
      device  = "/dev/disk/by-label/Warehouse";
      fsType  = "ntfs3";
      options = [
        "uid=1000" "gid=100"
        "umask=007"
        "nofail" "noauto"
        "x-systemd.automount" "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=10s"
        "force"
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
    "d /mnt/Warehouse    0755 babylinux users -"
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

  # NTFS3 kernel driver for the Warehouse HDD
  boot.supportedFilesystems.ntfs = true;

  # ==============================================================
  # AMD Radeon RX 5700 XT specific settings
  #
  # The 5700 XT is an RDNA1 card. It has mature driver support on Linux
  # and works very reliably. CoreCtrl is available if she ever wants
  # GPU monitoring but we keep it optional here.
  # ==============================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  # ==============================================================
  # Stability focused extras
  #
  # Since this is a machine you manage for someone else, we add a few
  # quality of life things that make it easier to support remotely.
  # ==============================================================
  environment.systemPackages = with pkgs; [
    cifs-utils
    ntfs3g

    # Remote support
    rustdesk          # Open source remote desktop — lets you help her
                      # remotely without needing to be physically present

    # Media
    vlc               # Reliable video player that plays anything
  ];

  # ==============================================================
  # Printing support
  #
  # CUPS handles printer management on Linux. Most modern printers
  # are detected automatically once this is enabled.
  # avahi enables network printer discovery.
  # ==============================================================
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
