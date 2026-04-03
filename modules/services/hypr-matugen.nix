# ===========================================================================
# hypr-matugen.nix — matugen color sync for Hyprland
#
# For Hyprland, the trigger is set-wallpaper.sh (called from autostart.conf
# and any manual wallpaper change). That script calls `matugen color hex`
# after setting the wallpaper via awww.
#
# This module handles the static setup: packages and config.toml.
# ===========================================================================
{ config, pkgs, lib, ... }:

{
  imports = [];

  home.packages = with pkgs; [
    matugen
    imagemagick
  ];

  home.file.".config/matugen/config.toml".text = ''
    [config]
    mode = "dark"
    reload_apps = false

    [templates.waybar]
    input_path = "/home/linuxury/nixos-config/dotfiles/hypr/waybar/colors.css.template"
    output_path = "/home/linuxury/.config/waybar/colors.css"
    post_hook = "pkill -USR2 waybar || true"

    [templates.swaync]
    input_path = "/home/linuxury/nixos-config/dotfiles/hypr/swaync/colors.css.template"
    output_path = "/home/linuxury/.config/swaync/colors.css"
    post_hook = "pkill swaync || true; swaync"

    [templates.hyprland]
    input_path = "/home/linuxury/.config/matugen/templates/templates/hyprland-colors.conf"
    output_path = "/home/linuxury/.config/hypr/colors.conf"
    post_hook = "PRIMARY=$(grep '^\\$primary ' /home/linuxury/.config/hypr/colors.conf | awk '{print $3}') && TERTIARY=$(grep '^\\$tertiary ' /home/linuxury/.config/hypr/colors.conf | awk '{print $3}') && OUTLINE=$(grep '^\\$outline_variant ' /home/linuxury/.config/hypr/colors.conf | awk '{print $3}') && hyprctl keyword general:col.active_border \"$PRIMARY $TERTIARY 45deg\" && hyprctl keyword general:col.inactive_border \"$OUTLINE\" || true"

    [templates.kitty]
    input_path = "/home/linuxury/.config/matugen/templates/templates/kitty-colors.conf"
    output_path = "/home/linuxury/.config/kitty/colors.conf"
    post_hook = "pkill -USR1 kitty || true"

    [templates.gtk]
    input_path = "/home/linuxury/.config/matugen/templates/templates/gtk-colors.css"
    output_path = "/home/linuxury/.config/gtk-4.0/colors.css"

    [templates.gtk-libadwaita]
    input_path = "/home/linuxury/nixos-config/dotfiles/hypr/gtk-libadwaita.css.template"
    output_path = "/home/linuxury/.config/gtk-4.0/libadwaita-matugen.css"

    [templates.rofi-window]
    input_path = "/home/linuxury/nixos-config/dotfiles/hypr/rofi/window.rasi.template"
    output_path = "/home/linuxury/.config/rofi/window.rasi"

    [templates.wofi]
    input_path = "/home/linuxury/nixos-config/dotfiles/hypr/wofi/colors.css.template"
    output_path = "/home/linuxury/.config/wofi/colors.css"

    [templates.hyprlock]
    input_path = "/home/linuxury/.config/matugen/templates/templates/hyprlock-colors.conf"
    output_path = "/home/linuxury/.config/hypr/colors-hyprlock.conf"
  '';
}