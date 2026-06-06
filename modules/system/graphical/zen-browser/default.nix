# ===========================================================================
# modules/system/graphical/zen-browser/default.nix — Zen Browser
#
# Zen is a Firefox-based browser focused on privacy and a clean UI.
# Not in nixpkgs — packaged via community flake (prebuilt binaries).
#
# Enable per host by importing this module:
#   ../../modules/system/graphical/zen-browser/default.nix
#
# Requires: flake input zen-browser (github:0xc000022070/zen-browser-flake)
# ===========================================================================

{ pkgs, inputs, ... }:

{
  # =========================================================================
  # Zen Browser — Firefox-based, privacy-focused browser
  # =========================================================================
  environment.systemPackages = [
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
