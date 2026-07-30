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

{ pkgs, lib, ... }:

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
    #   firefox     — primary browser (locked down via policies)
    #   libreoffice — office suite
    #   fluxer      — Discord client
    #   kdeconnect  — phone integration
    # ==============================================================
    ../../modules/system/graphical/firefox/default.nix
    #../../modules/system/graphical/helium/default.nix
    ../../modules/system/graphical/libreoffice/default.nix
    ../../modules/system/graphical/fluxer/default.nix
    #../../modules/services/kdeconnect/default.nix

    # ==============================================================
    # Desktop Environment — enable ONE (includes shell + greeter)
    # ==============================================================
    ../../modules/desktops/cosmic/default.nix
    #../../modules/desktops/gnome/default.nix
    #../../modules/desktops/kde/default.nix

    # ==============================================================
    # Compositor — enable ONE, pair with Shell + Greeter below
    # ==============================================================
    #../../modules/compositors/hyprland/default.nix
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
    # ==============================================================
    #../../modules/development/ai-tools/default.nix
    #../../modules/development/ai-tools/claude/default.nix
    #../../modules/development/ai-tools/opencode/default.nix
    #../../modules/development/ai-tools/local-llm/default.nix
    #../../modules/development/ai-tools/lm-studio/default.nix
    #../../modules/development/ai-tools/odysseus/default.nix

    # ==============================================================
    # Development — Editors (not a development host)
    # ==============================================================
    #../../modules/development/editors/neovim/default.nix
    #../../modules/development/editors/vscodium/default.nix
    #../../modules/development/editors/zed/default.nix

    # ==============================================================
    # Development — Languages (not a development host)
    # ==============================================================
    #../../modules/development/languages/python/default.nix
    #../../modules/development/languages/rust/default.nix

    # ==============================================================
    # Services
    #   auto-update — weekly nixos-rebuild from GitHub
    #   syncthing   — linuxury pair (admin access to sync config + vault)
    #   snapper     — BTRFS automatic snapshots
    # ==============================================================
    ../../modules/services/auto-update/default.nix
    ../../modules/services/syncthing/default.nix
    #../../modules/services/snapper/default.nix
    #../../modules/services/wallpaper-slideshow/default.nix
    #../../modules/services/samba/default.nix
    #../../modules/services/ntfy/default.nix
    #../../modules/services/vpn-qbittorrent/default.nix
    #../../modules/services/syncthing-babylinux/default.nix

    # ==============================================================
    # Users
    #   alex: description — GECOS display name (agenix secret)
    #   alex: packages    — per-user package set
    #   linuxury: ssh     — emergency admin access + Syncthing
    # ==============================================================
    ../../modules/users/alex/description/default.nix
    ../../modules/users/linuxury/ssh/default.nix
  ];

  # ==============================================================
  # Host identity
  # ==============================================================
  networking.hostName = "Alex-Laptop";

  services.nixos-auto-update.primaryUser = "alex";

  # ==============================================================
  # GPU driver selection
  #
  # AMD A-10 APU uses integrated Radeon graphics.
  # Same amdgpu driver as dedicated cards — works fine.
  # ==============================================================
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # ==============================================================
  # Filesystem — BTRFS with subvolumes
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

  # ==============================================================
  # Mount point directory + CIFS tools
  # ==============================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 alex users -"
    "d /mnt/MinisForum   0755 alex users -"
    "d /mnt/Torrents     0755 alex users -"
  ];

  environment.systemPackages = with pkgs; [
    cifs-utils

    # alex — everyday tools
    nix-output-monitor # Progress bar + TUI for nix builds (nom)
    gcompris           # 100+ educational activities — ages 2-10
    freetube           # YouTube without ads, algorithm, or shorts

    # ==============================================================
    # Host-specific apps
    # Special tools only this machine needs — editors, creative tools,
    # etc. go here so each host can enable/disable them independently.
    # ==============================================================
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
  #
  # Using latest stable rather than testing on this older hardware.
  # Older AMD APUs are very well supported and stable — no need
  # to risk RC kernel instability on a kid's school laptop.
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;           # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # ==============================================================
  # Performance tweaks for older hardware
  #
  # The A-10 APU is older and lower powered. These tweaks help it
  # run more smoothly with limited resources.
  # ==============================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
    "mitigations=auto"    # Keep security mitigations but let kernel
                          # choose the least impactful ones for this CPU
  ];

  # ==============================================================
  # Power management — important for older laptop battery
  #
  # Older batteries benefit even more from conservative power management.
  # ==============================================================
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
    HandleLidSwitch              = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey               = "suspend";
    IdleAction                   = "suspend";
    IdleActionSec                = "15min";
  };

  # ==============================================================
  # DNS filtering — same as Alex-Desktop
  # ==============================================================
  networking.nameservers = [ "1.1.1.3" "1.0.0.3" ];
  # mkForce needed because services.resolved sets this to "systemd-resolved"
  networking.networkmanager.dns = lib.mkForce "none";
  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [ "1.1.1.3" "1.0.0.3" ];
  };

  # ==============================================================
  # Flatpak — infrastructure kept, all remotes removed
  # Same approach as Alex-Desktop — see comment there for full explanation.
  # ==============================================================
  system.activationScripts.removeFlatpakRemotes.text = ''
    for remote in $(${pkgs.flatpak}/bin/flatpak remote-list --system \
                    --columns=name 2>/dev/null | tail -n +1); do
      ${pkgs.flatpak}/bin/flatpak remote-delete --system --force \
        "$remote" 2>/dev/null || true
    done
  '';

  # ==============================================================
  # Login time restrictions — same schedule as desktop
  # ==============================================================
  security.pam.services.login.text = lib.mkAfter ''
    account required pam_time.so
  '';

  environment.etc."security/time.conf".text = ''
    login;*;alex;Mo-Fr0800-2100|Sa-Su0800-2200
  '';

  # ==============================================================
  # Packages
  #
  # Alex's personal apps (freetube, krita, kdenlive, gcompris-qt,
  # libreoffice, hunspell) are declared in users/alex/home.nix.
  # Gaming packages (prismlauncher, jdk17) are in
  # modules/gaming/default.nix (imported above).
  # Graphical tools (kitty, showtime, etc.) are in modules/system/graphical/default.nix.
  # Shell tools (fastfetch, btop) are in modules/system/core/default.nix.
  # ==============================================================

  # ==============================================================
  # User account — no wheel, same restrictions as desktop
  # ==============================================================
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
    extraGroups  = [ "wheel" "networkmanager" ];
    home         = "/home/linuxury";
    createHome   = true;
    group        = "users";
    shell        = pkgs.zsh;
  };

  # Hide linuxury from the login screen — emergency account only
  services.displayManager.hiddenUsers = [ "linuxury" ];

  programs.zsh.enable = true;
}
