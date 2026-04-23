# ===========================================================================
# modules/desktop-environments/hyprland.nix — Hyprland Wayland Compositor
#
# Hyprland is a dynamic tiling Wayland compositor with smooth animations
# and a lot of customization potential.
#
# DankMaterialShell (DMS) provides the shell layer: bar, launcher,
# notifications, OSD, sidebar, dynamic matugen theming, and wallpaper
# management. dms-greeter replaces cosmic-greeter for the login screen.
#
# To enable on a host, import this module in that host's config.
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

let
  # BreezeX cursor theme — installed system-wide so dms-greeter (no
  # home-manager at login time) can use it on the login screen.
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
  imports = [
    # dms-greeter — NixOS-only module (cannot be in home-manager)
    inputs.dms.nixosModules.greeter
  ];

  # =========================================================================
  # Inject DMS and supporting modules into every user's Home Manager config
  # =========================================================================
  home-manager.sharedModules = [
    # DankMaterialShell shell layer — bar, launcher, notifications, OSD,
    # sidebar, dynamic theming, wallpaper management
    inputs.dms.homeModules.dank-material-shell
    {
      programs.dank-material-shell = {
        enable = true;
        systemd.enable = true;       # Auto-start with graphical session
        enableDynamicTheming = true; # Matugen wallpaper-based color theming
      };
    }

    # DankSearch — indexed filesystem search for the DMS launcher
    inputs.danksearch.homeModules.default
    {
      programs.dsearch.enable = true;
    }

    ../home/cosmic-theme.nix         # BreezeX-Light cursor + Tela-dark icons
    ../home/nautilus-bookmarks.nix   # GTK3 bookmarks + scripts for Nautilus
    {
      # Kitty — Hyprland handles transparency/blur, disable Kitty's own settings
      home.file.".config/kitty/hyprland-overrides.conf".source =
        ../../dotfiles/kitty/hyprland-overrides.conf;
    }
  ];

  # =========================================================================
  # Hyprland — the compositor itself
  #
  # withUWSM wraps Hyprland in the Universal Wayland Session Manager,
  # which handles systemd session integration properly.
  # =========================================================================
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # =========================================================================
  # XDG Portal for Hyprland
  # =========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "hyprland";
  };

  # =========================================================================
  # Polkit — Authentication agent
  # =========================================================================
  security.polkit.enable = true;

  # PAM — hyprlock needs this to authenticate with user password
  security.pam.services.hyprlock = {};

  # =========================================================================
  # Hyprland companion tools
  #
  # DMS replaces: waybar, wofi/rofi, swaync, swayosd, awww.
  # These are the remaining tools DMS does not provide.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Cursor theme — needed by dms-greeter (runs before home-manager)
    breezex-cursors

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

    # Notifications (for scripts/apps that call notify-send)
    libnotify

    # Theming
    nwg-look           # GTK theme settings for Wayland compositors
    qt6Packages.qt6ct  # Qt6 theme settings outside of KDE/GNOME

    # System tray / applets
    networkmanagerapplet  # WiFi tray icon
    blueman               # Bluetooth manager with tray icon

    # Polkit authentication agent
    polkit_gnome

    # Brightness control — required for laptop brightness keybinds
    brightnessctl

    # File manager — Nautilus (GNOME Files)
    # Requires local .desktop override to strip DBusActivatable=true
    nautilus
    sushi           # Quick file preview — press Space on any file
    tinysparql      # Tracker3 — provides org.freedesktop.Tracker3 for Nautilus search
    localsearch     # Tracker miners (filesystem crawler)

    # Media key control — playerctl play/pause/next/prev keybinds
    playerctl

    # IPC event listener — used by scripts watching Hyprland socket events
    socat
  ];

  # =========================================================================
  # Bluetooth — blueman for tray control
  # =========================================================================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        FastConnectable = true;
        AutoEnable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };
  services.blueman.enable = true;

  # =========================================================================
  # Display Manager — dms-greeter (greetd backend)
  #
  # DankMaterialShell's native login screen. Automatically shares theme
  # and wallpaper with the desktop session.
  #
  # configHome is derived from the host's first normal user — each machine
  # has exactly one, so the greeter inherits the correct wallpaper and
  # matugen color theme without any per-host configuration.
  # =========================================================================
  programs.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "hyprland";
    # Provide a full base config so the greeter's Hyprland instance picks up
    # the cursor theme. Without this, the script generates a minimal config
    # with no cursor settings, so the greeter defaults to the system cursor.
    # DMS_RUN_GREETER and misc must be repeated here — the script only injects
    # them automatically when no customConfig is provided.
    compositor.customConfig = ''
      env = DMS_RUN_GREETER,1
      env = XCURSOR_THEME,BreezeX-Light
      env = XCURSOR_SIZE,24
      env = HYPRCURSOR_THEME,BreezeX-Light
      env = HYPRCURSOR_SIZE,24

      misc {
          disable_hyprland_logo = true
      }
    '';
  };

  # Copy the primary user's DMS config into the greeter cache so it inherits
  # the active wallpaper and matugen color theme.
  # configHome/configFiles use types.path which doesn't survive evaluation,
  # so we inject the copy logic directly into the preStart script instead.
  systemd.services.greetd.preStart = lib.mkBefore (
    let
      normalUsers = lib.filterAttrs (_: u: u.isNormalUser) config.users.users;
      primaryUser = lib.head (lib.attrNames normalUsers);
      home = config.users.users.${primaryUser}.home;
      cacheDir = "/var/lib/dms-greeter";
    in
    ''
      for f in \
        "${home}/.config/DankMaterialShell/settings.json" \
        "${home}/.local/state/DankMaterialShell/session.json" \
        "${home}/.cache/DankMaterialShell/dms-colors.json"; do
        [ -f "$f" ] && cp --dereference "$f" ${cacheDir}/
      done
    ''
  );

  # =========================================================================
  # Keyring — Secret storage for apps
  #
  # GNOME Keyring works fine outside of GNOME.
  # dms-greeter uses the login PAM service for keyring unlock.
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # =========================================================================
  # Tracker — file indexer for Nautilus search
  # =========================================================================
  services.gnome.tinysparql.enable = true;
  services.gnome.localsearch.enable = true;

}
