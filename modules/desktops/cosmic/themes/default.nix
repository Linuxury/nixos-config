# ===========================================================================
# modules/desktops/cosmic/themes/default.nix — COSMIC-specific theme
#
# Extends the shared GTK base (cursor + icons + dark mode) with:
#   - gtk-decoration-layout for Firefox CSD window buttons
#   - CosmicTk config files (icon/cursor/size) for COSMIC's own theming API
#   - Blueman desktop entry: hides from app launcher (COSMIC has built-in BT)
#   - COSMIC Files sidebar favorites (network shares via RON format)
#
# For the cursor, icon theme, GTK dark mode, and dconf base, see:
#   modules/themes/gtk/default.nix
# ===========================================================================

{ ... }:

{
  imports = [ ../../../themes/gtk/default.nix ];

  # =========================================================================
  # Window button layout — GTK CSD apps (Firefox, GTK4 apps)
  # =========================================================================
  gtk.gtk3.extraConfig.gtk-decoration-layout = ":minimize,maximize,close";
  gtk.gtk4.extraConfig.gtk-decoration-layout = ":minimize,maximize,close";

  # =========================================================================
  # COSMIC appearance config
  #
  # COSMIC stores each setting as its own file under
  # ~/.config/cosmic/com.system76.CosmicTk/v1/.
  # Values are RON (Rusty Object Notation) — plain strings are quoted,
  # integers are bare numbers.
  #
  # Writing these declaratively means COSMIC always starts with the correct
  # theme regardless of what its UI may have previously set.
  # =========================================================================
  home.file.".config/cosmic/com.system76.CosmicTk/v1/icon_theme".text   = ''"Tela-dark"'';
  home.file.".config/cosmic/com.system76.CosmicTk/v1/cursor_theme".text = ''"BreezeX-Light"'';
  home.file.".config/cosmic/com.system76.CosmicTk/v1/cursor_size".text  = "24";

  # =========================================================================
  # Blueman — hide launcher entry on COSMIC
  #
  # COSMIC has its own Bluetooth panel applet. The blueman-applet autostart
  # is suppressed system-wide in core/default.nix via environment.etc.
  # This entry hides blueman-manager from the app launcher — it avoids a
  # duplicate "Bluetooth Manager" entry alongside COSMIC's own BT panel.
  # The binary remains available if called directly (e.g. for pairing).
  # =========================================================================
  home.file.".local/share/applications/blueman-manager.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Bluetooth Manager
    Exec=blueman-manager
    Hidden=true
  '';

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
          Path("/mnt/Torrents"),
      ]
    '';
  };
}
