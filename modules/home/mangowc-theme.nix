# ===========================================================================
# modules/home/mangowc-theme.nix — Cursor, icons, and GTK theme for MangoWC
#
# Injected into every user on a MangoWC host via home-manager.sharedModules
# in modules/desktop-environments/mangowc.nix.
#
# Sets:
#   - BreezeX-Light as the cursor theme (GTK + Wayland env)
#   - Tela-dark as the icon theme (GTK)
#   - adw-gtk3-dark as the GTK theme (dark mode for GTK3/4 apps)
#   - dconf dark mode preference (libadwaita apps respect this)
#   - Firefox CSD button layout (min/max/close on the right)
#
# Intentionally has NO COSMIC-specific config (.config/cosmic/...).
# For COSMIC hosts use modules/home/cosmic-theme.nix instead.
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
  #      so MangoWC and Wayland apps pick it up
  #   2. Creates ~/.icons/default/index.theme for X11 fallback (XWayland)
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
  # GTK theme — icons, cursor, and dark mode
  #
  # GTK apps read icon/cursor/theme from settings.ini. Setting them here
  # means GTK3, GTK4, and libadwaita apps all get consistent theming.
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
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      # Firefox (GTK CSD, native Wayland) reads button-layout from GTK settings
      # and GSettings — both must be set for min/max/close to appear correctly.
      gtk-decoration-layout = ":minimize,maximize,close";
    };
    gtk4 = {
      theme = config.gtk.theme; # Silence HM 26.05 default change warning
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-decoration-layout             = ":minimize,maximize,close";
      };
    };
  };

  # =========================================================================
  # dconf — dark mode and cursor for libadwaita / GSettings-aware apps
  #
  # org/gnome/desktop/interface is read by libadwaita (GTK4) apps even outside
  # GNOME. color-scheme=prefer-dark triggers dark mode in all libadwaita apps.
  # cursor-theme/cursor-size here backs up the GTK settings path above.
  #
  # org/gnome/desktop/wm/preferences button-layout: Firefox reads this via
  # GSettings in addition to the GTK settings.ini path — must match.
  # =========================================================================
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    cursor-theme = "BreezeX-Light";
    cursor-size  = 24;
  };

  dconf.settings."org/gnome/desktop/wm/preferences" = {
    button-layout = ":minimize,maximize,close";
  };
}
