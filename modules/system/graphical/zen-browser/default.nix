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
#
# By default also applies the "de-slop" managed policy shared with Firefox
# (../../../../dotfiles/firefox/policies.json — Zen is Firefox-based so the
# same policies.json schema applies): telemetry/AI/password-manager off,
# uBlock Origin and Proton Pass force-installed, uBlock preloaded with a
# hardened filter list plus the yt-shorts hider
# (github.com/gijsdev/ublock-hide-yt-shorts). Set
# programs.zen-browser.deSlop.enable = false; on a host to opt out.
# ===========================================================================

{ config, inputs, lib, ... }:

let
  cfg = config.programs.zen-browser;
in

{
  options.programs.zen-browser.deSlop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Apply the de-slop managed policy (dotfiles/firefox/policies.json) to Zen.";
  };

  config = {
    # =======================================================================
    # Zen Browser — Firefox-based, privacy-focused browser
    #
    # homeModules.default matches the packages.default channel used previously,
    # so this doesn't change which Zen build is installed — just how it's
    # managed. policies.Preferences (not profiles.<name>.settings) is used so
    # this doesn't need to know/match the existing on-disk profile name.
    # =======================================================================
    home-manager.users.linuxury = {
      imports = [ inputs.zen-browser.homeModules.default ];

      programs.zen-browser = {
        enable = true;

        policies = lib.mkIf cfg.deSlop.enable
          (builtins.fromJSON (builtins.readFile ../../../../dotfiles/firefox/policies.json)).policies;

        # gfx.color_management.hdr / .force_enabled — tried for Linux/Wayland
        # HDR video playback, reverted. Same result as Firefox: HDR did engage
        # (Hyprland switched the monitor to HDR mode) but video rendered with a
        # blown-out red tint. See modules/system/graphical/firefox/default.nix
        # for the Mozilla bug references — genuine upstream Gecko issue, not
        # fixable from config.
      };
    };
  };
}
