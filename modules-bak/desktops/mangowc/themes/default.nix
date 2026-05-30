# ===========================================================================
# modules/desktops/mangowc/themes/default.nix — MangoWC theme
#
# Extends the shared GTK base with MangoWC + Noctalia-specific settings:
#   - gtk-decoration-layout: Firefox and GTK CSD window buttons
#   - gtk4.extraCss: imports Noctalia's generated color CSS so GTK4 apps
#     follow the active Noctalia accent derived from the current wallpaper.
#     Noctalia writes ~/.config/gtk-4.0/noctalia.css on each launch.
#
# For the cursor, icon theme, GTK dark mode, and dconf base, see:
#   modules/themes/gtk/default.nix
# ===========================================================================

{ config, ... }:

{
  imports = [ ../../../themes/gtk/default.nix ];

  # =========================================================================
  # Window button layout — GTK CSD apps (Firefox, GTK4 apps)
  # =========================================================================
  gtk.gtk3.extraConfig.gtk-decoration-layout = ":minimize,maximize,close";
  gtk.gtk4 = {
    theme = config.gtk.theme; # Inherit from base (avoids duplicate set)
    extraConfig.gtk-decoration-layout = ":minimize,maximize,close";
    # Pull in Noctalia's generated color overrides. The file is written to
    # ~/.config/gtk-4.0/noctalia.css by the Noctalia bar on each launch.
    extraCss = ''@import url("noctalia.css");'';
  };
}
