# ===========================================================================
# modules/system/graphical/zen-browser/default.nix — Zen Browser
#
# Zen is a Firefox-based browser focused on privacy and a clean UI.
# Not in nixpkgs — packaged via community flake (prebuilt binaries).
#
# Imported by system/graphical/default.nix on every graphical host.
# Disabled by default — enable per host:
#
#   programs.zenBrowser.enable = true;
#
# Requires: flake input zen-browser (github:0xc000022070/zen-browser-flake)
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

{
  options.programs.zenBrowser = {
    enable = lib.mkEnableOption "Zen Browser";
  };

  config = lib.mkIf config.programs.zenBrowser.enable {

    # =========================================================================
    # Zen Browser — Firefox-based, privacy-focused browser
    # =========================================================================
    environment.systemPackages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

  };
}
