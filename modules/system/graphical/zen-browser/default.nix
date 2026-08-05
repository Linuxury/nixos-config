# ===========================================================================
# modules/system/graphical/zen-browser/default.nix — Zen Browser
#
# Zen is a Firefox-based browser focused on privacy and a clean UI.
# Not in nixpkgs — packaged via the community flake's home-manager module
# (github:0xc000022070/zen-browser-flake), scoped to linuxury only.
#
# Enable per host by importing this module:
#   ../../modules/system/graphical/zen-browser/default.nix
#
# Requires: flake input zen-browser (github:0xc000022070/zen-browser-flake)
# ===========================================================================

{ inputs, ... }:

{
  # =========================================================================
  # Zen Browser — Firefox-based, privacy-focused browser
  #
  # homeModules.default matches the packages.default channel used previously,
  # so this doesn't change which Zen build is installed — just how it's
  # managed. policies.Preferences (not profiles.<name>.settings) is used so
  # this doesn't need to know/match the existing on-disk profile name.
  # =========================================================================
  home-manager.users.linuxury = {
    imports = [ inputs.zen-browser.homeModules.default ];

    programs.zen-browser = {
      enable = true;

      # gfx.wayland.hdr — Linux/Wayland HDR video playback (experimental, uses
      # the color-management-v1 protocol Hyprland now speaks). Status =
      # "default" leaves it user-changeable in about:config.
      policies.Preferences."gfx.wayland.hdr" = {
        Value  = true;
        Status = "default";
      };
    };
  };
}
