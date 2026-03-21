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
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
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

  # =========================================================================
  # GTK window button layout
  #
  # GTK apps read this to decide which window buttons to draw in CSD mode.
  # Firefox (native Wayland, GTK CSD) reads button-layout from both the
  # GTK settings.ini AND the GSettings key — both must be set.
  # Without these, Firefox shows only a close button on COSMIC.
  #
  # Format: "left-buttons:right-buttons" — colon separates sides.
  # Applies to all users on all COSMIC hosts via sharedModules.
  # =========================================================================
  gtk.gtk3.extraConfig.gtk-decoration-layout = ":minimize,maximize,close";
  gtk.gtk4.extraConfig.gtk-decoration-layout = ":minimize,maximize,close";

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";   # Tells libadwaita/GTK4 apps to use dark mode
  };

  dconf.settings."org/gnome/desktop/wm/preferences" = {
    button-layout = ":minimize,maximize,close";
  };

  # =========================================================================
  # COSMIC Files — sidebar favorites
  #
  # COSMIC Files reads favorites from this RON file. Custom mount points
  # use the Path() variant — the last path segment becomes the display name,
  # so capitalized paths show as "Media-Server", "MinisForum", etc.
  #
  # Local drives appear automatically in COSMIC's Devices section —
  # only network shares need explicit entries here.
  #
  # Missing paths (e.g. on a laptop not on home LAN) are silently skipped.
  # Applies to all users on all COSMIC hosts via sharedModules.
  # =========================================================================
  home.file.".config/cosmic/com.system76.CosmicFiles/v1/favorites" = {
    force = true;
    text = ''
      [
          Home,
          Documents,
          Downloads,
          Music,
          Pictures,
          Videos,
          Path("/mnt/Media-Server"),
          Path("/mnt/MinisForum"),
      ]
    '';
  };
}
