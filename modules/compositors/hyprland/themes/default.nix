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
  # Qt theming — Kvantum + qt6ct
  #
  # Kvantum reads its active theme from kvantumrc. matugen writes the
  # kvantum-colors theme files to ~/.config/Kvantum/kvantum-colors/ on each
  # wallpaper change, so the palette stays in sync automatically.
  #
  # qt6ct.conf tells qt6ct to use the Kvantum style and the matugen color
  # scheme. QT_STYLE_OVERRIDE=kvantum (set in the Hyprland NixOS module)
  # ensures Qt apps load Kvantum without needing QT_QPA_PLATFORMTHEME=qt6ct.
  # =========================================================================
  home.file.".config/Kvantum/kvantumrc".text = ''
    [General]
    theme=kvantum-colors
  '';

  home.file.".config/qt6ct/qt6ct.conf".text = ''
    [Appearance]
    color_scheme_path=%h/.config/qt6ct/colors/matugen.conf
    custom_palette=true
    icon_theme=Tela-dark
    style=kvantum

    [Fonts]
    fixed=@Variant(\0\0\0@\0\0\0\x12JetBrainsMono Nerd Font\0\0\0\0\0\0\0\0\0\xfe\xff\xff\xff)
    general=@Variant(\0\0\0@\0\0\0\nNoto Sans\0\0\0\0\0\0\0\0\0\xfe\xff\xff\xff)
  '';

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
