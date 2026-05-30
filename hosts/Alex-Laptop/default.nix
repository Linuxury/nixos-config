# ===========================================================================
# hosts/Alex-Laptop/default.nix — Alex's Laptop (HP with AMD A-10 APU)
#
# Owner: alex
# Hardware: Older HP laptop, AMD A-10 APU (integrated graphics)
# Type: Laptop — kid focused
# Role: Kid's laptop — school, gaming, videos
#
# Enabled modules:
#   - AMD drivers
#   - COSMIC (default DE)
#   - Gaming
#   - Firefox with forced policies (via firefox.nix)
#
# Parental controls:
#   - Same as Alex-Desktop
#   - Extra power management for older battery
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    # ── System ──────────────────────────────────────────────────────────────
    # core: locale, fonts, nix daemon, base CLI packages, boot defaults.
    # graphical: Wayland stack, PipeWire audio, XDG portals, graphical base pkgs.
    # No nixos-hardware profile — generic AMD APU support via drivers module.
    ../../modules/system/core/default.nix
    ../../modules/system/graphical/default.nix

    # ── Hardware ────────────────────────────────────────────────────────────
    # drivers: GPU (AMD/NVIDIA/Intel) + OpenCL/VAAPI. Selected via hardware.gpu option.
    # openrgb: RGB lighting control daemon (not applicable on a laptop).
    ../../modules/hardware/drivers/default.nix
    #../../modules/hardware/openrgb/default.nix

    # ── Desktop Environments ─────────────────────────────────────────────────
    # Full DEs — include their own shell and greeter. Enable ONE.
    # COSMIC chosen: kid-friendly UI, parental controls integrate cleanly.
    ../../modules/desktops/cosmic/default.nix
    #../../modules/desktops/gnome/default.nix
    #../../modules/desktops/kde/default.nix

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
    # Not for a 6-year-old — intentionally excluded.
    #../../modules/development/default.nix

    # ── Services ────────────────────────────────────────────────────────────
    # auto-update: weekly nixos-rebuild from GitHub + Obsidian update log.
    # syncthing: linuxury pair — admin access to sync config and vault entries.
    # ai-tools: Claude Code, AI integrations (not appropriate for alex).
    # snapper: BTRFS automatic snapshots — timeline + pre/post around updates.
    # local-llm/samba/ntfy/vpn-qbittorrent: not applicable on this host.
    # syncthing-babylinux: babylinux's sync pair (babylinux hosts only).
    ../../modules/services/auto-update/default.nix
    ../../modules/services/syncthing/default.nix
    #../../modules/services/ai-tools/default.nix
    #../../modules/services/snapper/default.nix
    #../../modules/services/local-llm/default.nix
    #../../modules/services/wallpaper-slideshow/default.nix
    #../../modules/services/samba/default.nix
    #../../modules/services/ntfy/default.nix
    #../../modules/services/vpn-qbittorrent/default.nix
    #../../modules/services/syncthing-babylinux/default.nix

    # ── Users ───────────────────────────────────────────────────────────────
    # alex: primary user — display name, packages (no SSH key — kids don't SSH).
    # linuxury: emergency SSH access + admin management.
    ../../modules/users/alex/description/default.nix
    ../../modules/users/alex/packages/default.nix
    ../../modules/users/linuxury/ssh/default.nix
  ];

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Alex-Laptop";

  services.nixos-auto-update.primaryUser = "alex";

  # =========================================================================
  # GPU driver selection
  #
  # AMD A-10 APU uses integrated Radeon graphics.
  # Same amdgpu driver as dedicated cards — works fine.
  # =========================================================================
  hardware.gpu = "amd";

  # =========================================================================
  # Filesystem — BTRFS with subvolumes
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
    # Read-only for alex — he can browse media but not accidentally delete.
    # Automounts on first access, disconnects after 60s idle.
    # -----------------------------------------------------------------------
    "/mnt/Media-Server" = {
      device  = "//10.0.0.3/Media-Server";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=alex" "gid=users"
        "ro"
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
        "uid=alex" "gid=users"
        "ro"
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
        "uid=alex" "gid=users"
        "ro"
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
    "d /mnt/Media-Server 0755 alex users -"
    "d /mnt/MinisForum   0755 alex users -"
    "d /mnt/Torrents     0755 alex users -"
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
  #
  # Using latest stable rather than testing on this older hardware.
  # Older AMD APUs are very well supported and stable — no need
  # to risk RC kernel instability on a kid's school laptop.
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # =========================================================================
  # Performance tweaks for older hardware
  #
  # The A-10 APU is older and lower powered. These tweaks help it
  # run more smoothly with limited resources.
  # =========================================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
    "mitigations=auto"    # Keep security mitigations but let kernel
                          # choose the least impactful ones for this CPU
  ];

  # =========================================================================
  # Power management — important for older laptop battery
  #
  # Older batteries benefit even more from conservative power management.
  # =========================================================================
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC  = "ondemand";   # Balanced on AC
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";  # Aggressive saving on battery
      CPU_ENERGY_PERF_POLICY_ON_AC  = "balance-performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Conservative battery thresholds for older battery health
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0  = 80;

      PCIE_ASPM_ON_BAT = "powersupersave";

      # Aggressive disk power saving on battery
      DISK_APM_LEVEL_ON_BAT = "1";
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
  services.logind.settings.Login = {
    HandleLidSwitch              = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey               = "suspend";
    IdleAction                   = "suspend";
    IdleActionSec                = "15min";
  };

  # =========================================================================
  # DNS filtering — same as Alex-Desktop
  # =========================================================================
  networking.nameservers = [ "1.1.1.3" "1.0.0.3" ];
  # mkForce needed because services.resolved sets this to "systemd-resolved"
  networking.networkmanager.dns = lib.mkForce "none";
  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [ "1.1.1.3" "1.0.0.3" ];
  };

  # =========================================================================
  # Flatpak — infrastructure kept, all remotes removed
  # Same approach as Alex-Desktop — see comment there for full explanation.
  # =========================================================================
  system.activationScripts.removeFlatpakRemotes.text = ''
    for remote in $(${pkgs.flatpak}/bin/flatpak remote-list --system \
                    --columns=name 2>/dev/null | tail -n +1); do
      ${pkgs.flatpak}/bin/flatpak remote-delete --system --force \
        "$remote" 2>/dev/null || true
    done
  '';

  # =========================================================================
  # Login time restrictions — same schedule as desktop
  # =========================================================================
  security.pam.services.login.text = lib.mkAfter ''
    account required pam_time.so
  '';

  environment.etc."security/time.conf".text = ''
    login;*;alex;Mo-Fr0800-2100|Sa-Su0800-2200
  '';

  # =========================================================================
  # Packages
  #
  # Alex's personal apps (freetube, krita, kdenlive, gcompris-qt,
  # libreoffice, hunspell) are declared in users/alex/home.nix.
  # Gaming packages (prismlauncher, jdk17) are in
  # modules/gaming/default.nix (imported above).
  # Graphical tools (kitty, showtime, etc.) are in modules/system/graphical/default.nix.
  # Shell tools (fastfetch, btop) are in modules/system/core/default.nix.
  # =========================================================================

  # =========================================================================
  # User account — no wheel, same restrictions as desktop
  # =========================================================================
  users.users.alex = {
    isNormalUser = true;
    extraGroups  = [
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

  # Hide linuxury from the login screen — emergency account only
  services.displayManager.hiddenUsers = [ "linuxury" ];

  programs.zsh.enable = true;
}
