# ===========================================================================
# modules/users/babylinux-packages.nix — System packages for babylinux
#
# Imported by: Ryzen5800x, Asus-A15
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [

    # NixOS tools
    nix-output-monitor # Progress bar + TUI for nix builds (nom)

    # Communication
    zoom-us         # Video conferencing
  ];
}
