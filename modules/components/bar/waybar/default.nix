# ===========================================================================
# modules/components/bar/waybar/default.nix — Waybar status bar
#
# Compositor-agnostic status bar.
# Works on any wlr-layer-shell compositor (Hyprland, Niri, Sway, MangoWC…).
#
# When imported, this module:
#   1. Adds waybar to system packages.
#   2. Symlinks dotfiles/waybar/ → ~/.config/waybar/  (all users)
#   3. Writes ~/.config/hypr/components/bar.lua at HM activation
#      (placeholder for future Hyprland-specific bar keybinds).
#      The file is only loaded when Hyprland is the active compositor.
# ===========================================================================

{ pkgs, lib, ... }:

{
  config = {
    environment.systemPackages = [ pkgs.waybar ];

    home-manager.sharedModules = [
      ({ config, lib, ... }: {

        home.file.".config/waybar".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/waybar";

        home.activation.waybarHyprBinds = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          _target="$HOME/.config/hypr/components/bar.lua"
          _dir="$(dirname "$_target")"
          [ -d "$_dir" ] || mkdir -p "$_dir"
          [ -d "$HOME/.config/hypr" ] || exit 0
          # Placeholder — add Hyprland keybinds for bar interaction here
          printf '' > "$_target"
        '';
      })
    ];
  };
}
