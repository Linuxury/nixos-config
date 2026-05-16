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

{ config, pkgs, lib, ... }:

let
  # MangoWC session .desktop — tells QtGreet and any display manager
  # that MangoWC is an available Wayland session.
  mangowc-session = pkgs.writeTextDir "share/wayland-sessions/mangowc.desktop" ''
    [Desktop Entry]
    Name=MangoWC
    Comment=Lightweight Wayland Compositor (MangoWC + Noctalia)
    Exec=${pkgs.mangowc}/bin/mangowc
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
