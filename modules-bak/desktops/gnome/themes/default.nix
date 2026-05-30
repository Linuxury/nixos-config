# ===========================================================================
# modules/desktops/gnome/themes/default.nix — GNOME theme
#
# The shared GTK base provides everything GNOME needs:
#   BreezeX-Light cursor, Tela-dark icons, adw-gtk3-dark, dconf dark mode,
#   and dconf button-layout for Firefox CSD.
#
# GNOME handles window decorations via its own Shell — no extra
# gtk-decoration-layout override needed here (GNOME apps use GNOME's
# native CSD window management).
#
# For the cursor, icon theme, GTK dark mode, and dconf base, see:
#   modules/themes/gtk/default.nix
# ===========================================================================

{ ... }:

{
  imports = [ ../../../themes/gtk/default.nix ];
}
