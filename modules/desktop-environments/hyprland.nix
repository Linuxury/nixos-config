# ===========================================================================
# modules/desktop-environments/hyprland.nix — Hyprland Wayland Compositor
#
# Hyprland is a dynamic tiling Wayland compositor with smooth animations
# and a lot of customization potential. It's not a full DE like COSMIC or
# KDE — it's just a window manager, so you build the rest of the experience
# yourself (bar, launcher, notifications, etc).
#
# This module is ONLY enabled on your machines (linuxury).
# It's a learning/experimentation environment, not a daily driver yet.
#
# To enable on a host, import this module in that host's config.
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

let
  # BreezeX cursor theme — same derivation as cosmic-theme.nix
  # The greeter user has no home-manager, so we install it system-wide
  breezex-cursors = pkgs.stdenv.mkDerivation {
    pname   = "breezex-cursor-theme";
    version = "2.0.1";
    src = pkgs.fetchzip {
      url       = "https://github.com/ful1e5/BreezeX_Cursor/releases/download/v2.0.1/BreezeX.tar.xz";
      sha256    = "10fbvbls52cgp5kshlcxbh3nqarh2mwhpj0w5kkk4hrl3sdc1bcj";
      stripRoot = false;
    };
    dontBuild     = true;
    dontConfigure = true;
    installPhase  = ''
      mkdir -p $out/share/icons
      cp -r . $out/share/icons/
    '';
  };
in

{
  # =========================================================================
  # Per-host hardware options for the SwayNC Control Panel
  #
  # Set these in your host's default.nix to enable hardware-specific widgets.
  # Defaults are safe for desktop hosts (no backlight/battery).
  #
  # Example (ThinkPad):
  #   myModules.swaync.hasBacklight      = true;
  #   myModules.swaync.backlightDevice   = "amdgpu_bl1";
  #   myModules.swaync.hasKbBacklight    = true;
  #   myModules.swaync.kbBacklightDevice = "tpacpi::kbd_backlight";
  # =========================================================================
  options.myModules.swaync = {
    hasBacklight = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = "Display backlight present (laptop). Adds brightness slider.";
    };
    backlightDevice = lib.mkOption {
      type        = lib.types.str;
      default     = "";
      description = "Device name under /sys/class/backlight (e.g. amdgpu_bl1).";
    };
    hasKbBacklight = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = "Keyboard backlight present (laptop). Adds KB brightness slider.";
    };
    kbBacklightDevice = lib.mkOption {
      type        = lib.types.str;
      default     = "";
      description = "Device name under /sys/class/leds (e.g. tpacpi::kbd_backlight).";
    };
    hasWifi = lib.mkOption {
      type        = lib.types.bool;
      default     = true;
      description = "WiFi present. Adds WiFi toggle to buttons grid.";
    };
    hasBluetooth = lib.mkOption {
      type        = lib.types.bool;
      default     = true;
      description = "Bluetooth present. Adds BT toggle to buttons grid.";
    };
  };

  config = {

  # =========================================================================
  # Inject hypr-matugen into every user's Home Manager config
  # =========================================================================
  home-manager.sharedModules = [
    ../services/hypr-matugen.nix
    ../home/cosmic-theme.nix         # BreezeX-Light cursor + Tela-dark icons
    ../home/nautilus-bookmarks.nix   # GTK3 bookmarks + scripts for Nautilus
    ../home/swaync.nix               # Control Panel — host-aware config.json
    {
      # Kitty — Hyprland handles transparency/blur, disable Kitty's own settings
      home.file.".config/kitty/hyprland-overrides.conf".source =
        ../../dotfiles/kitty/hyprland-overrides.conf;
    }
  ];
  # =========================================================================
  # Hyprland — the compositor itself
  #
  # NixOS has a dedicated Hyprland module that handles all the Wayland
  # plumbing automatically. We just enable it.
  #
  # withUWSM wraps Hyprland in the Universal Wayland Session Manager,
  # which handles systemd session integration properly — recommended
  # for NixOS specifically.
  # =========================================================================
  programs.hyprland = {
    enable = true;
    withUWSM = true;   # Proper systemd session integration
    xwayland.enable = true; # Allows running X11 apps inside Hyprland
  };

  # =========================================================================
  # XDG Portal for Hyprland
  #
  # Hyprland uses xdg-desktop-portal-hyprland for screen sharing,
  # file pickers, and other desktop integration features.
  # =========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk  # Fallback for GTK apps
    ];
    config.common.default = "hyprland";
  };

  # =========================================================================
  # Polkit — Authentication agent
  #
  # Without a polkit agent, GUI apps can't ask for your password when
  # they need elevated permissions (e.g. mounting drives, system settings).
  # Hyprland doesn't include one by default unlike full DEs.
  # =========================================================================
  security.polkit.enable = true;

  # PAM — hyprlock needs this to authenticate with user password
  security.pam.services.hyprlock = {};

  # =========================================================================
  # Hyprland companion tools
  #
  # Since Hyprland is just a compositor, you need to bring your own
  # tools for everything else. These are the building blocks —
  # actual configuration of each lives in your dotfiles.
  #
  # Think of this as the toolkit. You decide how to use them.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Cursor theme — needed by SDDM greeter (no home-manager at login)
    breezex-cursors

    # Status bar
    waybar          # Highly customizable Wayland bar

    # Launchers
    wofi            # App launcher / dmenu replacement for Wayland
    rofi            # Alternative launcher with more features (rofi-wayland merged into rofi)

    # Notifications
    swaynotificationcenter  # Sway Notification Center — notification daemon + panel
    libnotify               # notify-send — sends notifications from scripts/apps

    # Wallpaper
    awww            # Animated wallpaper daemon (awww-daemon + awww img) — formerly swww

    # Screenshots
    grim            # Screenshot tool for Wayland
    slurp           # Region selector (used with grim)
    swappy          # Screenshot annotation tool

    # Screen recording
    wf-recorder     # Wayland screen recorder (lightweight, keybind toggle)
    wl-screenrec    # GPU-accelerated screen recorder (AMD/NVIDIA)

    # Night light
    wlsunset        # Wayland color temperature filter (auto sunset/sunrise)

    # Clipboard
    wl-clipboard    # Wayland clipboard (wl-copy / wl-paste commands)
    cliphist        # Clipboard history manager

    # Screen locking
    hyprlock        # Hyprland-native screen locker
    hypridle        # Idle management (dim, lock, suspend)

    # Audio
    pavucontrol     # PulseAudio volume mixer GUI
    swayosd         # Center-bottom OSD layer-shell window for volume/brightness

    # Theming
    nwg-look        # GTK theme settings for Wayland compositors
    qt6Packages.qt6ct  # Qt6 theme settings outside of KDE/GNOME

    # System tray / applets
    networkmanagerapplet  # WiFi tray icon
    blueman               # Bluetooth manager with tray icon

    # Polkit authentication agent
    # Lets GUI apps request elevated permissions (mount drives, etc.)
    # Autostarted via autostart.conf — must be in packages so the binary exists.
    polkit_gnome

    # Brightness control — required for laptop brightness keybinds
    brightnessctl

    # File manager — Nautilus (GNOME Files)
    # Works on Hyprland; Mutter.ServiceChannel warning is non-fatal.
    # Requires local .desktop override to strip DBusActivatable=true — otherwise
    # wofi/rofi launch it in --gapplication-service mode which fails silently.
    nautilus
    sushi              # Quick file preview — press Space on any file (package name in nixpkgs is "sushi", not gnome-sushi)
    # nautilus-admin not in nixpkgs — "Open as Administrator" handled via the shell script in nautilus-bookmarks.nix
    tinysparql      # Tracker3 / TinySPARQL — provides org.freedesktop.Tracker3 for Nautilus search
    localsearch     # Tracker miners (filesystem crawler, formerly tracker-miners)

    # Quickshell — Qt6/QML desktop shell toolkit
    # Used to build the custom shell: bar, dock, launcher, notifications, OSD,
    # sidebar, workspace overview, and lock screen.
    # Flake input declared in flake.nix with nixpkgs.follows for Qt version safety.
    inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
    qt6Packages.qt5compat  # Qt5 compat layer — enables Gaussian blur effects in Quickshell

    # Media key control — playerctl play/pause/next/prev keybinds
    playerctl

    # IPC event listener — used by col-width-auto.sh to watch Hyprland socket events
    socat
  ];

  # =========================================================================
  # Bluetooth — enabled here because Hyprland needs blueman for tray control
  # On COSMIC and KDE this is handled by the DE itself.
  # =========================================================================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true; # Bluetooth on automatically at startup
    settings = {
      General = {
        FastConnectable = true;    # Quick reconnect to known devices
        AutoEnable = true;         # Enable adapter on boot
      };
      Policy = {
        AutoEnable = true;         # Auto-connect trusted devices
      };
    };
  };
  services.blueman.enable = true;

  # =========================================================================
  # Display Manager — COSMIC Greeter
  #
  # COSMIC's native login screen. Works well with Hyprland as the compositor
  # — handles session selection and login, then launches Hyprland.
  # =========================================================================
  services.displayManager.cosmic-greeter.enable = true;

  # =========================================================================
  # Keyring — Secret storage for apps
  #
  # Without a keyring, apps like browsers and SSH agents lose saved
  # passwords on every reboot. GNOME Keyring works fine outside of GNOME.
  # cosmic-greeter uses the login PAM service for keyring unlock.
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # =========================================================================
  # Tracker — file indexer for Nautilus search
  #
  # Provides org.freedesktop.Tracker3.Miner.Files so Nautilus can index
  # and search files. Mutter.ServiceChannel is still unavailable (hard no
  # on Hyprland — requires gnome-shell), but that warning is non-fatal.
  # =========================================================================
  services.gnome.tinysparql.enable = true;
  services.gnome.localsearch.enable = true;

  # =========================================================================
  # Greeter wallpaper sync
  #
  # Problem: cosmic-greeter runs as its own user and can't read files under
  # /home/linuxury/, so it always shows a stale/hardcoded wallpaper.
  #
  # Solution:
  #   1. set-wallpaper.sh hardlinks the chosen wallpaper to
  #      /var/lib/wallpapers/current.jpg (world-readable, no sudo needed
  #      since linuxury owns the directory).
  #   2. A systemd path unit detects the change.
  #   3. A root service writes the COSMIC RON config into the greeter's
  #      home, so it displays the same wallpaper at the login screen.
  # =========================================================================
  systemd.tmpfiles.rules = [
    "d /var/lib/wallpapers 0755 linuxury users -"
  ];

  systemd.paths.sync-greeter-wallpaper = {
    description = "Watch current wallpaper and sync to cosmic-greeter";
    wantedBy    = [ "multi-user.target" ];
    pathConfig.PathChanged = "/var/lib/wallpapers/current.jpg";
  };

  systemd.services.sync-greeter-wallpaper = {
    description = "Sync cosmic-greeter background to current wallpaper";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "systemd-tmpfiles-setup.service" ];
    unitConfig.ConditionPathExists = "/var/lib/wallpapers/current.jpg";
    serviceConfig.Type = "oneshot";
    script = ''
      WALLPAPER="/var/lib/wallpapers/current.jpg"
      GREETER_BG_DIR="/var/lib/cosmic-greeter/.config/cosmic/com.system76.CosmicBackground/v1"
      mkdir -p "$GREETER_BG_DIR"
      printf 'true' > "$GREETER_BG_DIR/same-on-all"
      printf '(\n    output: "all",\n    source: Path("%s"),\n    filter_by_theme: false,\n    rotation_frequency: 0,\n    filter_method: Lanczos,\n    scaling_mode: Zoom,\n    sampling_method: Alphanumeric,\n)\n' \
        "$WALLPAPER" > "$GREETER_BG_DIR/all"
      chown -R cosmic-greeter:cosmic-greeter /var/lib/cosmic-greeter/.config
      # Restart daemon so it picks up the new wallpaper immediately
      # (daemon reads config once at boot — restart makes it re-read)
      systemctl restart cosmic-greeter-daemon.service
    '';
  };

  }; # end config
}
