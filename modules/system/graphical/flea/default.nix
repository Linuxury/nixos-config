# ===========================================================================
# modules/system/graphical/flea/default.nix — Flea file manager (trial)
#
# Keyboard-first GPUI file manager (https://github.com/thisisgm/flea), built
# for Omarchy. Only the native `flea-gui` window is packaged
# (pkgs/flea/package.nix); the Quickshell picker and `omarchy` update/default
# hooks need Omarchy and are not available here. Installed as an alternate:
# Thunar stays the folder default. Launch with `flea` or `flea --gui <dir>`.
# ===========================================================================

{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      flea = prev.callPackage ../../../../pkgs/flea/package.nix { };
    })
  ];

  environment.systemPackages = [ pkgs.flea ];
}
