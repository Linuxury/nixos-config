# ===========================================================================
# modules/desktop-environments/gnome.nix — GNOME Desktop Environment
#
# GNOME is a polished, GTK-based desktop environment with strong Wayland
# support and a focus on simplicity. Good baseline for testing GTK app
# behavior and portal compatibility.
#
# Display manager: GDM (GNOME's native login screen, Wayland-first)
#
# To enable on a host, import this module. Use one DE at a time —
# do not import alongside kde.nix or cosmic.nix (display manager conflict).
# ===========================================================================

{ config, pkgs, ... }:

{
  # =========================================================================
  # GNOME Desktop
  #
  # Enables GNOME Shell plus all core GNOME apps (Files, Text Editor,
  # Calendar, Contacts, etc.). Extras go in environment.systemPackages below.
  # =========================================================================
  services.desktopManager.gnome.enable = true;

  # =========================================================================
  # Display Manager — GDM
  #
  # GDM is GNOME's native display manager. Wayland session is the default.
  # =========================================================================
  services.displayManager.gdm = {
    enable   = true;
    wayland  = true;
  };

  # =========================================================================
  # XWayland — X11 compatibility layer
  #
  # Allows X11 apps to run inside the Wayland session.
  # =========================================================================
  programs.xwayland.enable = true;

  # =========================================================================
  # XDG Portal for GNOME
  #
  # xdg-desktop-portal-gnome handles file pickers, screen sharing, etc.
  # GTK portal provides fallback for any interface GNOME has not yet covered.
  # =========================================================================
  xdg.portal = {
    enable       = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "gnome;gtk";
  };

  # =========================================================================
  # GNOME-specific packages
  #
  # Core GNOME apps are pulled in automatically by the desktopManager option.
  # Only add things not bundled by default.
  # Do not add anything already present in graphical-base.nix.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    gnome-tweaks  # Exposes advanced GNOME settings not in the default Settings app
  ];
}
