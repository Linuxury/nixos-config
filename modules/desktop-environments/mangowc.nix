# ===========================================================================
# modules/desktop-environments/mangowc.nix — MangoWC + Noctalia Shell
#
# MangoWC is a lightweight wlroots/scenefx-based Wayland compositor.
# Noctalia is the shell layer: bar, launcher, notifications, widgets.
#
# Login screen: greetd backend + tuigreet frontend (TUI, runs on TTY directly
# — no Wayland compositor needed for the greeter, avoids cage SIGABRT on RDNA3).
#
# To enable on a host, import this module in that host's config.
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

let
  # Wrapper that sets cursor env vars before exec-ing MangoWC.
  # greetd launches this directly, so MangoWC inherits XCURSOR_THEME
  # at startup (before systemd environment.d is sourced — too late otherwise).
  mangowc-start = pkgs.writeShellScript "mangowc-start" ''
    export XCURSOR_THEME=BreezeX-Light
    export XCURSOR_SIZE=24
    exec ${pkgs.mangowc}/bin/mangowc
  '';

  # Session .desktop — registers MangoWC with tuigreet's session picker.
  mangowc-session = pkgs.writeTextDir "share/wayland-sessions/mangowc.desktop" ''
    [Desktop Entry]
    Name=MangoWC
    Comment=Lightweight Wayland Compositor (MangoWC + Noctalia)
    Exec=${mangowc-start}
    Type=Application
    DesktopNames=MangoWC
    Keywords=wayland;compositor;tiling
  '';
in

{
  # =========================================================================
  # Shared Home Manager modules — cursor, icons, GTK theme, Nautilus extras
  #
  # Injected into every user on this host via sharedModules so all users
  # inherit the same cursor, icon theme, and Nautilus bookmarks/scripts
  # without duplicating config per-user.
  # =========================================================================
  home-manager.sharedModules = [
    ../home/cosmic-theme.nix       # BreezeX-Light cursor + Tela-dark icons + adw-gtk3-dark
    ../home/nautilus-bookmarks.nix # Sidebar bookmarks + right-click Copy Path / Open as Root
  ];

  # =========================================================================
  # Tracker — file indexer for Nautilus search
  #
  # tinysparql (Tracker3) provides the org.freedesktop.Tracker3 DBus service
  # that Nautilus queries when you search. localsearch crawls the filesystem
  # and feeds results into Tracker's SPARQL store.
  # Without these, Nautilus search returns no results.
  # =========================================================================
  services.gnome.tinysparql.enable = true;
  services.gnome.localsearch.enable  = true;

  # =========================================================================
  # Nix binary cache — pre-built Noctalia binaries (avoids local Qt compile)
  #
  # Noctalia publishes all packages to Cachix. Without this the first build
  # would recompile Quickshell and its Qt dependencies from source (~30 min).
  # =========================================================================
  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  # =========================================================================
  # Login manager — greetd + tuigreet
  #
  # greetd is a minimal login daemon (replaces dms-greeter/cosmic-greeter).
  # tuigreet is a TUI frontend that runs directly on the TTY — no Wayland
  # compositor required for the greeter itself.
  #
  # cage + qtgreet was attempted but cage 0.2.1 crashes with SIGABRT on
  # RDNA3 (RX 7900 XTX) before it can open a display. tuigreet sidesteps
  # this entirely since it never touches the GPU.
  #
  # --time        shows current time on the login screen
  # --remember    pre-fills the last logged-in username
  # --sessions    points tuigreet at the wayland-sessions directory so it
  #               can offer MangoWC (and any other registered sessions)
  # =========================================================================
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = ''
          ${pkgs.tuigreet}/bin/tuigreet \
            --time \
            --remember \
            --sessions /run/current-system/sw/share/wayland-sessions
        '';
      };
    };
  };

  # Make the MangoWC session visible to tuigreet's session picker
  environment.pathsToLink = [ "/share/wayland-sessions" ];

  # =========================================================================
  # XDG Desktop Portal — screen capture, file picker, screenshots, etc.
  #
  # xdg-desktop-portal-wlr handles wlroots-based compositors (MangoWC).
  # xdg-desktop-portal-gtk handles file pickers and GTK app integration.
  # =========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-wlr
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "wlr";
  };

  # =========================================================================
  # Polkit — privilege escalation for GUI apps (mount drives, etc.)
  # =========================================================================
  security.polkit.enable = true;

  # =========================================================================
  # Keyring — secret storage for apps (browser passwords, SSH keys, etc.)
  # Unlocked automatically on login via PAM integration.
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # =========================================================================
  # Bluetooth — desktop always-on (no suspend needed on desktop)
  # =========================================================================
  hardware.bluetooth = {
    powerOnBoot = true;
    settings = {
      General.FastConnectable = true;
      Policy.AutoEnable = true;
    };
  };

  # =========================================================================
  # Packages — compositor, shell layer, and companion tools
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # -----------------------------------------------------------------------
    # Compositor + shell
    # -----------------------------------------------------------------------
    mangowc           # Wayland compositor (wlroots + scenefx based)
    noctalia-shell    # Shell layer: bar, launcher, notifications, widgets
    noctalia-qs       # Quickshell-based QtQuick toolkit used by noctalia-shell

    # Session .desktop (registers MangoWC in QtGreet's session list)
    mangowc-session

    # -----------------------------------------------------------------------
    # Screenshots
    # -----------------------------------------------------------------------
    grim              # Screenshot tool for Wayland
    slurp             # Region selector (used with grim)
    swappy            # Screenshot annotation tool

    # -----------------------------------------------------------------------
    # Screen recording
    # -----------------------------------------------------------------------
    wf-recorder       # Wayland screen recorder (lightweight, keybind toggle)
    wl-screenrec      # GPU-accelerated screen recorder (AMD/NVIDIA)

    # -----------------------------------------------------------------------
    # Night light / color temperature
    # -----------------------------------------------------------------------
    wlsunset          # Auto sunset/sunrise color temperature filter

    # -----------------------------------------------------------------------
    # Clipboard
    # -----------------------------------------------------------------------
    wl-clipboard      # wl-copy / wl-paste commands
    cliphist          # Clipboard history manager

    # -----------------------------------------------------------------------
    # Screen locking
    # -----------------------------------------------------------------------
    swaylock          # Wayland-native screen locker (works on any wlroots WM)

    # -----------------------------------------------------------------------
    # Audio
    # -----------------------------------------------------------------------
    pavucontrol       # PulseAudio volume mixer GUI

    # -----------------------------------------------------------------------
    # Notifications
    # -----------------------------------------------------------------------
    libnotify         # notify-send command for scripts/apps

    # -----------------------------------------------------------------------
    # Theming
    # -----------------------------------------------------------------------
    nwg-look           # GTK theme settings for Wayland compositors
    qt6Packages.qt6ct  # Qt6 theme settings outside of KDE/GNOME

    # -----------------------------------------------------------------------
    # File manager
    # -----------------------------------------------------------------------
    nautilus              # GNOME Files — graphical file manager
    sushi                 # Quick file preview — press Space on a file in Nautilus
    tinysparql            # Tracker3 — org.freedesktop.Tracker3 for Nautilus search
    localsearch           # Tracker miners — filesystem crawler that feeds Tracker

    # -----------------------------------------------------------------------
    # IPC / scripting
    # -----------------------------------------------------------------------
    socat                 # Socket relay — used by scripts watching compositor events

    # -----------------------------------------------------------------------
    # System tray / applets
    # -----------------------------------------------------------------------
    networkmanagerapplet  # WiFi tray icon
    blueman               # Bluetooth manager with tray icon
    polkit_gnome          # Polkit authentication agent

    # -----------------------------------------------------------------------
    # Media / brightness
    # -----------------------------------------------------------------------
    playerctl             # Media key control (play/pause/next/prev)
    brightnessctl         # Monitor brightness control
  ];
}
