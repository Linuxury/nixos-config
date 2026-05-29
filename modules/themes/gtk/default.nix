# ===========================================================================
# modules/themes/gtk/default.nix — Shared GTK and cursor base theme
#
# Home Manager module imported by all compositor and desktop theme modules.
# Provides:
#   - BreezeX-Light cursor (Wayland env + GTK + X11 fallback)
#   - adw-gtk3-dark GTK theme + Tela-dark icons + BreezeX cursor via GTK config
#   - dconf dark mode + cursor settings for libadwaita / GSettings apps
#   - dconf button-layout for Firefox CSD window buttons
#
# Each compositor/desktop imports this and adds only its unique config:
#   compositors/hyprland/themes/default.nix  → + gtk-decoration-layout
#   desktops/cosmic/themes/default.nix       → + CosmicTk files + favorites
#   desktops/gnome/themes/default.nix        → (base is sufficient for GNOME)
#   desktops/mangowc/themes/default.nix      → + gtk-decoration-layout + noctalia.css
#
# Extracted from the 4 separate theme modules to eliminate the BreezeX
# derivation duplication. One sha256 to update, one place to change.
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
  # the sha256 below. Update it here and all theme modules benefit at once.
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
  #      so Wayland compositors (COSMIC, Hyprland, Niri, MangoWC) pick it up
  #   2. Creates ~/.icons/default/index.theme for X11 / XWayland fallback
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
  # GTK3, GTK4, and libadwaita apps all read from settings.ini.
  # Compositor/desktop-specific modules extend gtk3/gtk4.extraConfig
  # with additional keys (e.g. gtk-decoration-layout) — HM merges them.
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
      theme = config.gtk.theme; # Silence HM 26.05 default change warning
      extraConfig.gtk-application-prefer-dark-theme = 1;
    };
  };

  # =========================================================================
  # dconf — dark mode, cursor, and window button layout
  #
  # org/gnome/desktop/interface is read by libadwaita/GTK4 apps even outside
  # GNOME. color-scheme=prefer-dark triggers dark mode in all libadwaita apps.
  #
  # org/gnome/desktop/wm/preferences: button-layout is read by Firefox (via
  # GSettings) in addition to the GTK settings.ini path — both must be set.
  # =========================================================================
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme  = "prefer-dark";
    cursor-theme  = "BreezeX-Light";
    cursor-size   = 24;
  };

  dconf.settings."org/gnome/desktop/wm/preferences" = {
    button-layout = ":minimize,maximize,close";
  };
}
