# ===========================================================================
# modules/components/bar/waybar/default.nix — Waybar status bar
#
# Compositor-agnostic status bar.
# Works on any wlr-layer-shell compositor (Hyprland, Niri, Sway, MangoWC…).
#
# When imported, this module:
#   1. Adds waybar to system packages.
#   2. Writes ~/.config/hypr/components/bar.lua at HM activation
#      (layout-cycle keybind for the Hyprland scrolling layout).
#      The file is only loaded when Hyprland is the active compositor.
#
# TODO: add home-manager module for waybar config.json + style.css
# ===========================================================================

{ pkgs, lib, ... }:

{
  config = {
    environment.systemPackages = [ pkgs.waybar ];

    home-manager.sharedModules = [
      ({ lib, ... }: {
        home.activation.waybarHyprBinds = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          _target="$HOME/.config/hypr/components/bar.lua"
          _dir="$(dirname "$_target")"
          [ -d "$_dir" ] || mkdir -p "$_dir"
          [ -d "$HOME/.config/hypr" ] || exit 0
          printf '%s\n' \
            'local mod = "SUPER"' \
            '-- Layout cycle — cycles scrolling layout column width' \
            'hl.bind(mod .. " + SHIFT + Space", hl.dsp.exec_cmd("~/.config/hypr/waybar/scripts/layout.sh cycle"))' \
            > "$_target"
        '';
      })
    ];
  };
}
