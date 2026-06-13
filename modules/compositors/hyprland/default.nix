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

{ pkgs, lib, ... }:

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
    # Desktop components (bar, launcher, notifications) are compositor-agnostic.
    # Import them in your host config from modules/components/:
    #   modules/components/bar/waybar/default.nix           — waybar
    #   modules/components/launcher/wofi/default.nix        — wofi + rofi
    #   modules/components/notifications/swaync/default.nix — swaync
  ];

  # Switch SDDM greeter compositor from Weston to KWin.
  #
  # Root cause of no-cursor: Weston sends wl_seat.capabilities(2) = keyboard
  # only and never updates to include the pointer bit, even though libinput
  # detects the keyboard-dongle devices (Keychron Ultra-Link, Lemokey Link)
  # as pointer devices. Qt correctly sees no pointer capability and never
  # creates a wl_pointer → wl_pointer.set_cursor is never called → no cursor,
  # regardless of cursor theme. Confirmed via WAYLAND_DEBUG=1 trace.
  #
  # KWin properly advertises pointer capability for these combo devices and
  # natively supports layer-shell-qt (auto-added by the NixOS SDDM module
  # when compositor = "kwin"), which makes QT_WAYLAND_SHELL_INTEGRATION=
  # layer-shell actually work.
  services.displayManager.sddm.wayland.compositor = "kwin";

  # Override the NixOS kwin GreeterEnvironment (which only sets layer-shell)
  # with our complete set. lib.mkForce wins over the NixOS module's plain
  # assignment so all vars are present.
  services.displayManager.sddm.settings.General.GreeterEnvironment = lib.mkForce
    "QT_QPA_PLATFORM=wayland,QT_QPA_PLATFORMTHEME=,QT_WAYLAND_SHELL_INTEGRATION=layer-shell,XCURSOR_THEME=BreezeX-Light,XCURSOR_SIZE=24,XCURSOR_PATH=/run/current-system/sw/share/icons,XDG_DATA_DIRS=/run/current-system/sw/share";

  # KWin (SDDM compositor) uses logind directly for seat management — it does NOT
  # talk to seatd. When KWin holds the DRM device via logind, seatd can never
  # complete its initialisation and times out after 90 s (systemd kills it).
  #
  # Hyprland's aquamarine backend uses libseat with the "auto" mode: seatd first,
  # then logind. After each seatd crash the socket disconnects, aquamarine logs
  # "Couldn't dispatch libseat events" in a flood, and Hyprland eventually dies.
  #
  # Fix: force libseat to use the logind backend, skipping seatd entirely.
  # Both KWin and Hyprland then talk to the same logind seat, which is exactly
  # what logind was designed for.
  #
  # seatd must also be disabled: the greeters/sddm module enables it, but here
  # KWin already holds the DRM device via logind so seatd can never start.
  # It hangs for its full 90 s startup timeout, which blocks graphical.target,
  # which blocks UWSM, causing a ~65 s delay before Hyprland launches.
  environment.sessionVariables.LIBSEAT_BACKEND = "logind";
  services.seatd.enable = lib.mkForce false;

  services.displayManager.sddm.settings.Theme = {
    CursorTheme = "BreezeX-Light";
    CursorSize  = "24";
  };

  # Keep tmpfiles symlinks for sddm user home so libXcursor finds BreezeX-Light
  # via the home dir path (~/.icons) in addition to XCURSOR_PATH.
  systemd.tmpfiles.rules = [
    "L /var/lib/sddm/.icons/BreezeX-Light            - - - - /run/current-system/sw/share/icons/BreezeX-Light"
    "L /var/lib/sddm/.local/share/icons/BreezeX-Light - - - - /run/current-system/sw/share/icons/BreezeX-Light"
  ];

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
    # networkmanagerapplet: removed — Noctalia bar widget handles network
    # blueman: installed by services.blueman.enable (core); no tray applet started

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
  # Tracker — file indexer for Nautilus search
  # =========================================================================
  services.gnome.tinysparql.enable = true;
  services.gnome.localsearch.enable = true;
}
