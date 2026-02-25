# ===========================================================================
# modules/desktop-environments/niri.nix — Niri Wayland Compositor
#
# Niri is a scrollable-tiling Wayland compositor. Unlike Hyprland's
# dynamic tiling, Niri arranges windows in an infinite horizontal scroll —
# new windows always open to the right, never overlapping.
#
# It's a newer, more opinionated compositor with a simpler config format
# compared to Hyprland. Good for experimentation and learning a different
# tiling philosophy.
#
# Like Hyprland, this is ONLY enabled on your machines (linuxury).
# ===========================================================================

{ config, pkgs, inputs, ... }:

{
  # =========================================================================
  # Niri — the compositor itself
  #
  # NixOS has a dedicated Niri module in nixpkgs.
  # xwayland support in Niri is handled differently than Hyprland —
  # it requires xwayland-satellite as a separate companion process
  # rather than being built in.
  # =========================================================================
  programs.niri = {
    enable = true;
  };

  # =========================================================================
  # XWayland Satellite — X11 app support for Niri
  #
  # Niri doesn't have built-in XWayland support like Hyprland does.
  # xwayland-satellite runs as a companion process that bridges X11 apps
  # into Niri's Wayland environment. You start it in your Niri config.
  # =========================================================================
  programs.xwayland.enable = true;

  # =========================================================================
  # XDG Portal for Niri
  #
  # Niri doesn't have its own portal implementation yet.
  # xdg-desktop-portal-gnome works well as a fallback and handles
  # screen sharing, file pickers, and other integrations reliably.
  # =========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "gnome";
  };

  # =========================================================================
  # Polkit — same reason as Hyprland, WMs don't include this by default
  # =========================================================================
  security.polkit.enable = true;

  # =========================================================================
  # Niri companion tools
  #
  # Very similar stack to Hyprland since both are bare compositors.
  # Some tools are shared concepts, some are Niri-specific.
  # Actual configuration lives in your dotfiles.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Status bar
    waybar             # Same bar works for both Hyprland and Niri

    # Launcher
    fuzzel             # Lightweight launcher, popular in Niri setups
    rofi-wayland       # Alternative if you prefer it from Hyprland

    # Notifications
    dunst
    libnotify

    # Wallpaper
    swww               # Works well with Niri

    # Screenshots
    grim
    slurp
    swappy

    # Clipboard
    wl-clipboard
    cliphist

    # Screen locking
    swaylock
    swayidle

    # XWayland bridge for Niri
    xwayland-satellite # Bridges X11 apps into Niri without full XWayland

    # Theming
    nwg-look
    qt6ct

    # System tray
    networkmanagerapplet
    blueman
  ];

  # =========================================================================
  # Bluetooth — same as Hyprland, no built-in BT management in bare WMs
  # =========================================================================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # =========================================================================
  # Keyring — same reasoning as Hyprland
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
}
