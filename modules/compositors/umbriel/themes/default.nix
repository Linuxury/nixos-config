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
  # wallpaper change, so the palette stays in sync automatically — Noctalia
  # has no Kvantum template, so this part of the pipeline stays as-is.
  #
  # qt6ct.conf itself stays fully Nix-managed (Noctalia's own "qt" theming
  # is compiled-in, not a shell apply.sh like kitty/gtk — it only writes a
  # separate color file at colors/noctalia.conf, confirmed by reading its
  # undo.sh, which just removes that file). color_scheme_path points there
  # instead of matugen's colors/matugen.conf — matugen no longer generates
  # that file (see matugen/default.nix).
  # =========================================================================
  home.file.".config/Kvantum/kvantumrc".text = ''
    [General]
    theme=kvantum-colors
  '';

  home.file.".config/qt6ct/qt6ct.conf" = {
    force = true;
    text = ''
    [Appearance]
    color_scheme_path=%h/.config/qt6ct/colors/noctalia.conf
    custom_palette=true
    icon_theme=Tela-dark
    style=kvantum

    [Fonts]
    fixed=@Variant(\0\0\0@\0\0\0\x12JetBrainsMono Nerd Font\0\0\0\0\0\0\0\0\0\xfe\xff\xff\xff)
    general=@Variant(\0\0\0@\0\0\0\nNoto Sans\0\0\0\0\0\0\0\0\0\xfe\xff\xff\xff)
  '';
  };
}
