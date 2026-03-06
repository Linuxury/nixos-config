# ===========================================================================
# modules/users/babylinux-packages.nix — System packages for babylinux
#
# Imported by: Ryzen5800x, Asus-A15
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [

    # Office
    onlyoffice-desktopeditors  # Word/Excel/PowerPoint compatible office suite

    # Communication
    zoom-us         # Video conferencing
  ];
}
