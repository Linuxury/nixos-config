# ===========================================================================
# modules/components/bar/waybar/default.nix — Waybar status bar
#
# Compositor-agnostic status bar.
# Works on any wlr-layer-shell compositor (Hyprland, Niri, Sway…).
#
# When imported, this module:
#   1. Adds waybar to system packages.
#   2. Symlinks dotfiles/waybar/ → ~/.config/waybar/  (all users)
#   3. If Hyprland is present: writes ~/.config/hypr/components/bar.lua
#      (placeholder for Hyprland-specific bar keybinds; skipped on all
#      other compositors — this module itself is compositor-agnostic).
# ===========================================================================

{ pkgs, ... }:

{
  config = {
    environment.systemPackages = [ pkgs.waybar ];

    home-manager.sharedModules = [
      ({ config, lib, ... }: {

        home.file.".config/waybar".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/waybar";

        home.activation.waybarHyprBinds = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          # Only run on Hyprland hosts — skip silently on all others
          [ -d "$HOME/.config/hypr" ] || exit 0
          _target="$HOME/.config/hypr/components/bar.lua"
          [ -d "$(dirname "$_target")" ] || mkdir -p "$(dirname "$_target")"
          # Placeholder — add Hyprland keybinds for bar interaction here
          printf '' > "$_target"
        '';
      })
    ];
  };
}
