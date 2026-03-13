# ===========================================================================
# modules/home/cosmic-theme.nix — Shared icon and cursor theme for COSMIC
#
# Injected into every COSMIC host via home-manager.sharedModules in
# modules/desktop-environments/cosmic.nix. All users on any COSMIC host
# (linuxury, babylinux, alex) inherit these settings automatically.
#
# Sets:
#   - Tela-dark as the icon theme (GTK + COSMIC)
#   - BreezeX-Light as the cursor theme (GTK + COSMIC + X11/Wayland env)
# ===========================================================================

{ pkgs, ... }:

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
  #      so Wayland compositors (COSMIC, Hyprland, Niri) pick it up
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
  # COSMIC and most apps respect gtk-icon-theme-name and
  # gtk-cursor-theme-name from settings.ini. Setting them here means
  # GTK3, GTK4, and libadwaita apps all get consistent theming.
  # =========================================================================
  gtk = {
    enable    = true;
    iconTheme = {
      name    = "Tela-dark";
      package = pkgs.tela-icon-theme;
    };
    cursorTheme = {
      name    = "BreezeX-Light";
      package = breezex-cursors;
      size    = 24;
    };
  };

  # =========================================================================
  # COSMIC appearance config
  #
  # COSMIC stores each setting as its own file under
  # ~/.config/cosmic/com.system76.CosmicTk/v1/.
  # Values are serialized as RON (Rusty Object Notation) — plain strings
  # are just quoted strings, integers are bare numbers.
  #
  # Writing these declaratively means COSMIC always starts with the correct
  # theme regardless of what its UI may have previously set.
  # =========================================================================
  home.file.".config/cosmic/com.system76.CosmicTk/v1/icon_theme".text   = ''"Tela-dark"'';
  home.file.".config/cosmic/com.system76.CosmicTk/v1/cursor_theme".text = ''"BreezeX-Light"'';
  home.file.".config/cosmic/com.system76.CosmicTk/v1/cursor_size".text  = "24";
}
