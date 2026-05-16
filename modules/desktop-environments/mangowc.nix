# ===========================================================================
# modules/desktop-environments/mangowc.nix — MangoWC + Noctalia Shell
#
# MangoWC is a lightweight wlroots/scenefx-based Wayland compositor.
# Noctalia is the shell layer: bar, launcher, notifications, widgets.
#
# Login screen: greetd backend + QtGreet frontend (rendered inside cage,
# a single-app kiosk compositor — cage exits as soon as QtGreet hands off).
#
# To enable on a host, import this module in that host's config.
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  # MangoWC session .desktop — tells QtGreet and any display manager
  # that MangoWC is an available Wayland session.
  mangowc-session = pkgs.writeTextDir "share/wayland-sessions/mangowc.desktop" ''
    [Desktop Entry]
    Name=MangoWC
    Comment=Lightweight Wayland Compositor (MangoWC + Noctalia)
    Exec=mangowc
    Type=Application
    DesktopNames=MangoWC
    Keywords=wayland;compositor;tiling
  '';
in

{
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
  # Login manager — greetd + QtGreet
  #
  # greetd is a minimal login daemon (replaces dms-greeter/cosmic-greeter).
  # QtGreet is a Qt/QML graphical frontend for greetd; it needs a Wayland
  # compositor to render into, so we run it inside cage (kiosk compositor).
  #
  # Flow: greetd → cage → qtgreet → user picks session → cage exits → MangoWC
  # =========================================================================
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.cage}/bin/cage -s -- ${pkgs.qtgreet}/bin/qtgreet";
      };
    };
  };

  # Make the MangoWC session visible to QtGreet's session picker
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
    # Login manager
    # -----------------------------------------------------------------------
    qtgreet           # Qt/QML graphical greeter frontend for greetd
    cage              # Minimal kiosk compositor that hosts qtgreet

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
