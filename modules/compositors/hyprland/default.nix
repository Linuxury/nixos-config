# ===========================================================================
# modules/compositors/hyprland/default.nix — Hyprland Wayland Compositor
#
# Hyprland is a dynamic tiling Wayland compositor with smooth animations
# and extensive customization potential.
#
# Shell layer and greeter are separate — import them in your host config:
#   modules/shells/dms/default.nix       # DankMaterialShell (bundles greeter)
#   modules/shells/wayle/default.nix     # Wayle (needs greeters/sddm)
#   modules/shells/noctalia/default.nix  # Noctalia (needs greeters/sddm)
#
# To enable on a host, import this module in that host's config.
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

let
  # Wrapper that launches the UWSM-managed Hyprland session with stdout/stderr
  # redirected to the journal. Without this, UWSM prints session-init messages
  # directly to the TTY, causing a brief flash of text on a blank screen between
  # the greeter exiting and Hyprland's first frame appearing.
  hyprland-session-start = pkgs.writeShellScript "hyprland-session-start" ''
    exec ${pkgs.systemd}/bin/systemd-cat -t hyprland-session \
      uwsm start hyprland-uwsm.desktop
  '';

  hyprland-session-pkg = pkgs.runCommand "hyprland-session"
    { passthru.providedSessions = [ "hyprland-session" ]; }
    ''
      mkdir -p $out/share/wayland-sessions
      cat > $out/share/wayland-sessions/hyprland-session.desktop <<'EOF'
      [Desktop Entry]
      Name=Hyprland
      Comment=Hyprland Wayland Compositor (UWSM)
      Exec=${hyprland-session-start}
      Type=Application
      DesktopNames=Hyprland
      Keywords=wayland;compositor;tiling
      EOF
    '';

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
    # SwayNC — declares options.myModules.swaync.* and injects hm.nix
    ./services/swaync/default.nix
  ];

  # BreezeX-Light cursor for the SDDM greeter.
  #
  # Four-layer approach:
  #   1. QT_WAYLAND_SHELL_INTEGRATION=layer-shell in GreeterEnvironment → Qt6
  #      uses wlr-layer-shell, which receives wl_pointer focus in Weston kiosk
  #      mode. Without this, the greeter surface gets no pointer focus and Qt
  #      never calls wl_pointer.set_cursor → cursor stays invisible.
  #   2. GreeterEnvironment + [Theme] CursorTheme → Qt6 greeter process gets
  #      XCURSOR_THEME, XCURSOR_PATH, XDG_DATA_DIRS for wl_pointer.set_cursor.
  #   3. sddm.environment → Weston inherits SDDM's process env (XCURSOR_THEME
  #      + XCURSOR_PATH) for any compositor-level cursor rendering.
  #   4. tmpfiles symlinks in sddm user's home (~/.icons, ~/.local/share/icons)
  #      so libXcursor finds the theme without relying on XCURSOR_PATH at all.
  systemd.tmpfiles.rules = [
    "L /var/lib/sddm/.icons/BreezeX-Light           - - - - /run/current-system/sw/share/icons/BreezeX-Light"
    "L /var/lib/sddm/.local/share/icons/BreezeX-Light - - - - /run/current-system/sw/share/icons/BreezeX-Light"
  ];

  systemd.services.sddm.environment = {
    XCURSOR_THEME = "BreezeX-Light";
    XCURSOR_SIZE  = "24";
    XCURSOR_PATH  = "/run/current-system/sw/share/icons";
  };

  services.displayManager.sddm.settings.General.GreeterEnvironment =
    "QT_QPA_PLATFORM=wayland,QT_QPA_PLATFORMTHEME=,QT_WAYLAND_SHELL_INTEGRATION=layer-shell,XCURSOR_THEME=BreezeX-Light,XCURSOR_SIZE=24,XCURSOR_PATH=/run/current-system/sw/share/icons,XDG_DATA_DIRS=/run/current-system/sw/share";

  services.displayManager.sddm.settings.Theme = {
    CursorTheme = "BreezeX-Light";
    CursorSize  = "24";
  };

  # =========================================================================
  # Shared Home Manager modules — injected into every user on this host.
  # These are compositor-level concerns, not shell-specific.
  # =========================================================================
  home-manager.sharedModules = [
    ./themes/default.nix                          # BreezeX-Light cursor + Tela-dark icons + GTK
    ./matugen/default.nix                          # matugen color sync on wallpaper change
    {
      # Kitty — Hyprland handles transparency/blur; disable Kitty's own settings
      home.file.".config/kitty/hyprland-overrides.conf".source =
        ../../../dotfiles/kitty/hyprland-overrides.conf;
    }
  ];

  # nautilus-bookmarks hardcodes /home/linuxury/ paths — scope to linuxury only.
  home-manager.users.linuxury = {
    imports = [ ../../system/graphical/nautilus/default.nix ];
  };

  # =========================================================================
  # Hyprland — the compositor itself
  #
  # withUWSM wraps Hyprland in the Universal Wayland Session Manager,
  # which handles systemd session integration properly.
  # =========================================================================
  programs.hyprland = {
    enable      = true;
    withUWSM    = true;
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

  # Register the quiet session wrapper so greeters can offer it.
  services.displayManager.sessionPackages = [ hyprland-session-pkg ];

  # =========================================================================
  # Polkit — Authentication agent
  # =========================================================================
  security.polkit.enable = true;

  # PAM — hyprlock needs this to authenticate with user password
  security.pam.services.hyprlock = {};

  # =========================================================================
  # Keyring — Secret storage for apps
  #
  # GNOME Keyring works fine outside of GNOME.
  # PAM integration: greetd path handled by shells/dms;
  #                  login/TTY fallback always present here.
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # =========================================================================
  # Hyprland companion tools
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
    nwg-look            # GTK theme settings for Wayland compositors
    qt6Packages.qt6ct   # Qt6 theme settings outside of KDE/GNOME

    # System tray / applets
    networkmanagerapplet  # WiFi tray icon
    blueman               # Bluetooth manager with tray icon

    # Polkit authentication agent
    polkit_gnome

    # Brightness control — required for laptop brightness keybinds
    brightnessctl

    # File manager — Nautilus (GNOME Files)
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
  # Bluetooth — Hyprland-specific tuning (base enabled in graphical-base.nix)
  #
  # graphical-base.nix sets enable + powerOnBoot = false (mkDefault).
  # Override powerOnBoot to true here so Hyprland hosts come up with
  # the adapter on — useful with desktop Waybar tray on a known device.
  # FastConnectable + AutoEnable speed up reconnection to paired headsets.
  # =========================================================================
  hardware.bluetooth = {
    powerOnBoot = true;
    settings = {
      General = {
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  # =========================================================================
  # Tracker — file indexer for Nautilus search
  # =========================================================================
  services.gnome.tinysparql.enable = true;
  services.gnome.localsearch.enable = true;
}
