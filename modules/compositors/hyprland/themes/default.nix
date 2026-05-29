# ===========================================================================
# modules/compositors/hyprland/themes/default.nix — Hyprland theme
#
# Extends the shared GTK base with Hyprland-specific settings:
#   - gtk-decoration-layout: tells Firefox and GTK CSD apps which window
#     buttons to draw (min/max/close on the right). Must be in both GTK
#     settings.ini and GSettings (set via dconf in the gtk base above).
#
# For the cursor, icon theme, GTK dark mode, and dconf base, see:
#   modules/themes/gtk/default.nix
# ===========================================================================

{ ... }:

{
  imports = [ ../../../themes/gtk/default.nix ];

  # =========================================================================
  # Window button layout — GTK CSD apps (Firefox, GTK4 apps)
  #
  # Without this, Firefox on Hyprland shows only a close button because
  # GTK reads gtk-decoration-layout from settings.ini. The GSettings path
  # (org/gnome/desktop/wm/preferences:button-layout) is handled by the
  # gtk base above.
  # =========================================================================
  gtk.gtk3.extraConfig.gtk-decoration-layout = ":minimize,maximize,close";
  gtk.gtk4.extraConfig.gtk-decoration-layout = ":minimize,maximize,close";
}
