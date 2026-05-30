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

{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    # ── System ──────────────────────────────────────────────────────────────
    # core: locale, fonts, nix daemon, base CLI packages, boot defaults.
    # graphical: Wayland stack, PipeWire audio, XDG portals, graphical base pkgs.
    # No nixos-hardware profile needed — generic AMD support via drivers module.
    ../../modules/system/core/default.nix
    ../../modules/system/graphical/default.nix

    # ── Hardware ────────────────────────────────────────────────────────────
    # drivers: GPU (AMD/NVIDIA/Intel) + OpenCL/VAAPI. Selected via hardware.gpu option.
    # openrgb: RGB lighting control daemon (not applicable on this build).
    ../../modules/hardware/drivers/default.nix
    #../../modules/hardware/openrgb/default.nix

    # ── Compositor / Desktop Environment ────────────────────────────────────
    # Wayland compositors: hyprland (tiling), mangowc (floating), niri (scrollable tiling).
    # Full desktop environments: cosmic (System76), gnome, kde.
    # Enable ONE — each manages its own greeter (greetd) and display session.
    ../../modules/desktops/kde/default.nix
    #../../modules/desktops/cosmic/default.nix
    #../../modules/compositors/hyprland/default.nix
    #../../modules/compositors/mangowc/default.nix
    #../../modules/compositors/niri/default.nix
    #../../modules/desktops/gnome/default.nix

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
    # local-llm: Ollama local model runner (disabled — insufficient RAM).
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
  networking.hostName = "Ryzen5800x";

  # =========================================================================
  # GPU driver selection
  # =========================================================================
  hardware.gpu = "amd";

  services.nixos-auto-update.primaryUser = "babylinux";

  services.displayManager.defaultSession = "plasma";

  # =========================================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on desktop
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

  # =========================================================================
  # Mount point directory + CIFS tools
  # =========================================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 babylinux users -"
    "d /mnt/MinisForum   0755 babylinux users -"
    "d /mnt/Torrents     0755 babylinux users -"
    "d /mnt/Warehouse    0755 babylinux users -"
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

  # NTFS3 kernel driver for the Warehouse HDD
  boot.supportedFilesystems.ntfs = true;

  # =========================================================================
  # AMD Radeon RX 5700 XT specific settings
  #
  # The 5700 XT is an RDNA1 card. It has mature driver support on Linux
  # and works very reliably. CoreCtrl is available if she ever wants
  # GPU monitoring but we keep it optional here.
  # =========================================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  # =========================================================================
  # Stability focused extras
  #
  # Since this is a machine you manage for someone else, we add a few
  # quality of life things that make it easier to support remotely.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    cifs-utils
    ntfs3g

    # Remote support
    rustdesk          # Open source remote desktop — lets you help her
                      # remotely without needing to be physically present

    # Media
    vlc               # Reliable video player that plays anything
  ];

  # =========================================================================
  # Printing support
  #
  # CUPS handles printer management on Linux. Most modern printers
  # are detected automatically once this is enabled.
  # avahi enables network printer discovery.
  # =========================================================================
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
