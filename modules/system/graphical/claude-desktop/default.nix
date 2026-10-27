# ===========================================================================
# modules/system/graphical/claude-desktop/default.nix — Claude Desktop
#
# Official Linux beta, packaged from Anthropic's own .deb in
# pkgs/claude-desktop/package.nix (version + hash live there).
# Sign-in needs a Secret Service; Hyprland/Niri/Umbriel/COSMIC already
# enable gnome-keyring.
#
# Overlay is scoped here, so only hosts importing this module fetch it.
# ===========================================================================

{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      claude-desktop = prev.callPackage ../../../../pkgs/claude-desktop/package.nix {};
    })
  ];

  environment.systemPackages = [ pkgs.claude-desktop ];
}
