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
    rofi-wayland    # Alternative launcher with more features

    # Notifications
    dunst           # Lightweight notification daemon
    libnotify       # Sends notifications (needed by many apps)

    # Wallpaper
    hyprpaper       # Hyprland's own wallpaper tool
    swww            # Animated wallpaper alternative

    # Screenshots
    grim            # Screenshot tool for Wayland
    slurp           # Region selector (used with grim)
    swappy          # Screenshot annotation tool

    # Clipboard
    wl-clipboard    # Wayland clipboard (wl-copy / wl-paste commands)
    cliphist        # Clipboard history manager

    # Screen locking
    swaylock        # Screen locker for Wayland
    swayidle        # Idle management (dims/locks after inactivity)

    # Theming
    nwg-look        # GTK theme settings for Wayland compositors
    qt6ct           # Qt6 theme settings outside of KDE/GNOME

    # System tray / applets
    networkmanagerapplet  # WiFi tray icon
    blueman               # Bluetooth manager with tray icon
  ];

  # =========================================================================
  # Bluetooth — enabled here because Hyprland needs blueman for tray control
  # On COSMIC and KDE this is handled by the DE itself.
  # =========================================================================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true; # Bluetooth on automatically at startup
  };
  services.blueman.enable = true;

  # =========================================================================
  # Keyring — Secret storage for apps
  #
  # Without a keyring, apps like browsers and SSH agents lose saved
  # passwords on every reboot. GNOME Keyring works fine outside of GNOME.
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
}
