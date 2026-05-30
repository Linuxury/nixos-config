# ===========================================================================
# modules/home/gnome-theme.nix — Cursor and GTK theme for GNOME
#
# Injected into every GNOME host via home-manager.sharedModules in
# modules/desktop-environments/gnome.nix. All users on any GNOME host
# inherit these settings automatically.
#
# Sets:
#   - BreezeX-Light as the cursor theme (GTK + X11/Wayland env + dconf)
#   - Tela-dark as the icon theme (GTK)
#   - Dark mode preference for GTK4/libadwaita apps
# ===========================================================================

{ pkgs, config, ... }:

let
  # =========================================================================
  # BreezeX cursor theme — not in nixpkgs, fetched from GitHub releases
  #
  # BreezeX is a refined KDE Breeze cursor with larger sizes and cleaner
  # rendering. The v2.0.1 bundle ships three variants: Black, Dark, Light.
  # BreezeX-Light is used here as the default.
  #
  # To upgrade: run nix-prefetch-url --unpack <new release URL> and update
  # the sha256 below.
  # =========================================================================
  breezex-cursors = pkgs.stdenv.mkDerivation {
    pname   = "breezex-cursor-theme";
    version = "2.0.1";

    src = pkgs.fetchzip {
      url       = "https://github.com/ful1e5/BreezeX_Cursor/releases/download/v2.0.1/BreezeX.tar.xz";
      sha256    = "10fbvbls52cgp5kshlcxbh3nqarh2mwhpj0w5kkk4hrl3sdc1bcj";
      stripRoot = false; # archive has multiple top-level dirs (BreezeX, BreezeX-Black, …)
    };

    dontBuild     = true;
    dontConfigure = true;

    installPhase = ''
      mkdir -p $out/share/icons
      cp -r . $out/share/icons/
    '';
  };

in

{
  # =========================================================================
  # Cursor — BreezeX-Light
  #
  # home.pointerCursor handles three layers at once:
  #   1. Sets XCURSOR_THEME + XCURSOR_SIZE in the systemd user environment
  #      so GNOME on Wayland picks it up
  #   2. Creates ~/.icons/default/index.theme for X11 fallback
  #   3. Writes cursor settings to GTK config (gtk.enable = true below)
  # =========================================================================
  home.pointerCursor = {
    name       = "BreezeX-Light";
    package    = breezex-cursors;
    size       = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # =========================================================================
  # GTK theme — icons and cursor
  #
  # GTK3, GTK4, and libadwaita apps read these from settings.ini.
  # =========================================================================
  gtk = {
    enable = true;
    theme = {
      name    = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name    = "Tela-dark";
      package = pkgs.tela-icon-theme;
    };
    cursorTheme = {
      name    = "BreezeX-Light";
      package = breezex-cursors;
      size    = 24;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4 = {
      theme = config.gtk.theme;
      extraConfig.gtk-application-prefer-dark-theme = 1;
    };
  };

  # =========================================================================
  # GNOME dconf settings
  #
  # GNOME reads cursor-theme and cursor-size from dconf to set the pointer
  # system-wide. Without these, GNOME falls back to no theme (white box).
  # =========================================================================
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";    # libadwaita/GTK4 apps use dark mode
    cursor-theme = "BreezeX-Light";  # cursor shape mappings
    cursor-size  = 24;
  };

  dconf.settings."org/gnome/desktop/wm/preferences" = {
    button-layout = ":minimize,maximize,close";
  };
}
