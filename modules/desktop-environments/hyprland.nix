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

{ config, pkgs, inputs, ... }:

{
  # =========================================================================
  # Inject hypr-matugen into every user's Home Manager config
  # =========================================================================
  home-manager.sharedModules = [
    ../services/hypr-matugen.nix
    ../home/cosmic-theme.nix   # BreezeX-Light cursor + Tela-dark icons
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
    # Status bar
    waybar          # Highly customizable Wayland bar

    # Launchers
    wofi            # App launcher / dmenu replacement for Wayland
    rofi            # Alternative launcher with more features (rofi-wayland merged into rofi)

    # Notifications
    swaynotificationcenter  # Sway Notification Center — notification daemon + panel
    libnotify               # notify-send — sends notifications from scripts/apps

    # Wallpaper
    swww            # Animated wallpaper daemon (swww-daemon + swww img)

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
    wob             # Lightweight volume/brightness overlay bar

    # Audio
    pavucontrol     # PulseAudio volume mixer GUI

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

    # File managers
    yazi            # Terminal file manager with matugen theming
    nautilus        # GUI file manager — GTK4/libadwaita, uses gvfs for smb:// shares
                    # gvfs + samba already enabled in graphical-base.nix

    # Quickshell — Qt6/QML desktop shell toolkit
    # Used to build the custom shell: bar, dock, launcher, notifications, OSD,
    # sidebar, workspace overview, lock screen, and greetd login manager.
    # Flake input declared in flake.nix with nixpkgs.follows for Qt version safety.
    inputs.quickshell.packages.${pkgs.system}.default
    qt6Packages.qt5compat  # Qt5 compat layer — enables Gaussian blur effects in Quickshell

    # Media key control — playerctl play/pause/next/prev keybinds
    playerctl
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
  # Display Manager — greetd + tuigreet
  #
  # greetd is a minimal, flexible login manager designed for Wayland.
  # tuigreet is a terminal-based greeter for greetd — no heavy UI,
  # works well in TTY before the compositor starts.
  #
  # --time       → show clock on the login screen
  # --remember   → pre-fills the last username
  # --sessions   → lists all installed Wayland session .desktop files
  #                (Hyprland installs one automatically via withUWSM)
  # =========================================================================
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --sessions /run/current-system/sw/share/wayland-sessions";
        user    = "greeter";
      };
    };
  };

  # =========================================================================
  # Keyring — Secret storage for apps
  #
  # Without a keyring, apps like browsers and SSH agents lose saved
  # passwords on every reboot. GNOME Keyring works fine outside of GNOME.
  # greetd handles the PAM login so we enable the keyring unlock there.
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
}
