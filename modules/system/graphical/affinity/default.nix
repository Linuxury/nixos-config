# ===========================================================================
# modules/system/graphical/affinity/default.nix — Affinity v3 (Wine)
#
# Makes pkgs.affinity-v3 (Photo / Designer / Publisher) available on any
# graphical host. Nothing is applied unless programs.affinity.enable = true.
#
# The overlay modifies nixpkgs, so it must only be applied when explicitly
# opted in — applying it unconditionally causes garnix cache queries on every
# rebuild even when Affinity is never installed.
#
# Imported by: modules/system/graphical/default.nix
#
# To enable on a host:
#   programs.affinity.enable = true;
# ===========================================================================

{ inputs, config, lib, pkgs, ... }:

let cfg = config.programs.affinity; in

{
  options.programs.affinity.enable = lib.mkEnableOption "Affinity v3 via Wine (affinity-nix)";

  config = lib.mkIf cfg.enable {
    # affinity-nix overlay — evaluated in our nixpkgs context (which has
    # allowUnfree = true in core). The package became unfree in a recent update
    # and can no longer be consumed via inputs.affinity-nix.packages.* because
    # that path uses the flake's own nixpkgs (no allowUnfree). The overlay uses
    # prev.callPackage, so it inherits our nixpkgs config.
    nixpkgs.overlays = [ inputs.affinity-nix.overlays.default ];

    environment.systemPackages = [ pkgs.affinity-v3 ];
  };
}
