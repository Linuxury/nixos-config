# ===========================================================================
# modules/compositors/umbriel/themes/default.nix — Umbriel theme
#
# Extends the shared GTK base with Kvantum + qt6ct wiring — toolkit-level
# config, not Hyprland-specific, so reused verbatim from
# compositors/hyprland/themes/default.nix.
#
# gtk-decoration-layout (window buttons for GTK CSD apps) is intentionally
# left out here: Umbriel's appearance.prefer_no_csd defaults to true (its
# own border-only decoration), so whether GTK apps still need this GSettings
# override is untested. Revisit once Umbriel is actually running.
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
  # scheme. Unlike Hyprland's module, QT_STYLE_OVERRIDE isn't set here yet —
  # untested whether Umbriel needs the same override; add it once confirmed.
  # =========================================================================
  home.file.".config/Kvantum/kvantumrc".text = ''
    [General]
    theme=kvantum-colors
  '';

  home.file.".config/qt6ct/qt6ct.conf" = {
    force = true;
    text = ''
    [Appearance]
    color_scheme_path=%h/.config/qt6ct/colors/matugen.conf
    custom_palette=true
    icon_theme=Tela-dark
    style=kvantum

    [Fonts]
    fixed=@Variant(\0\0\0@\0\0\0\x12JetBrainsMono Nerd Font\0\0\0\0\0\0\0\0\0\xfe\xff\xff\xff)
    general=@Variant(\0\0\0@\0\0\0\nNoto Sans\0\0\0\0\0\0\0\0\0\xfe\xff\xff\xff)
  '';
  };
}
