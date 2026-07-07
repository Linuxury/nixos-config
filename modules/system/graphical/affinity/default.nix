# ===========================================================================
# modules/system/graphical/affinity/default.nix — Affinity v3 (Wine)
#
# Makes pkgs.affinity-v3 (Photo / Designer / Publisher) available on any
# graphical host by applying the affinity-nix overlay.  Nothing is installed
# by default — add pkgs.affinity-v3 to a host's packages to enable it.
#
# The garnix binary cache is added here (not in core) so headless servers
# never configure a cache they will never use.
#
# Imported by: modules/system/graphical/default.nix
#
# To install on a host, add to its packages list:
#   pkgs.affinity-v3
# ===========================================================================

{ inputs, ... }:

{
  # affinity-nix overlay — evaluated in our nixpkgs context (which has
  # allowUnfree = true in core). The package became unfree in a recent update
  # and can no longer be consumed via inputs.affinity-nix.packages.* because
  # that path uses the flake's own nixpkgs (no allowUnfree). The overlay uses
  # prev.callPackage, so it inherits our nixpkgs config.
  nixpkgs.overlays = [ inputs.affinity-nix.overlays.default ];

  # garnix binary cache — provides pre-built Wine for affinity-nix so we
  # never have to compile Wine from source (which takes many hours).
  nix.settings = {
    substituters      = [ "https://cache.garnix.io" ];
    trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };
}
