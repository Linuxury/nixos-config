# ===========================================================================
# modules/desktops/gnome/default.nix — GNOME Desktop Environment
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
  # Home Manager — inject GNOME theme and extensions for all users
  #
  # Applies BreezeX-Light cursor, Tela-dark icons, dark GTK theme, and
  # GNOME dconf cursor settings to every user managed by Home Manager on
  # this host. Without this, GNOME has no cursor theme and renders a
  # white box placeholder.
  #
  # Extensions are installed as packages and enabled via dconf so they
  # load automatically on login without any manual toggling.
  # =========================================================================
  home-manager.sharedModules = [
    ./themes/default.nix
    ({ pkgs, ... }: {
      home.packages = with pkgs.gnomeExtensions; [
        dash-to-dock
        blur-my-shell
        user-themes
        appindicator
        caffeine
        user-themes-x
        wallpaper-slideshow
        app-grid-wizard
      ];

      dconf.settings."org/gnome/shell" = {
        enabled-extensions = [
          "dash-to-dock@micxgx.gmail.com"
          "blur-my-shell@aunetx"
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "appindicatorsupport@rgcjonas.gmail.com"
          "caffeine@patapon.info"
          "user-theme-x@tuberry.github.io"
          "azwallpaper@azwallpaper.gitlab.com"
          "app-grid-wizard@mirzadeh.pro"
        ];
      };

      dconf.settings."org/gnome/shell/extensions/app-grid-wizard" = {
        enabled = true;
      };
    })
  ];

  # =========================================================================
  # GNOME-specific packages
  #
  # Core GNOME apps are pulled in automatically by the desktopManager option.
  # Only add things not bundled by default.
  # Do not add anything already present in system/graphical.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    gnome-tweaks  # Exposes advanced GNOME settings not in the default Settings app
  ];
}
