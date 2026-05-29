# ===========================================================================
# modules/users/alex/packages/default.nix — System packages for alex
#
# Imported by: Alex-Desktop, Alex-Laptop
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [

    # NixOS tools
    nix-output-monitor # Progress bar + TUI for nix builds (nom)

    # Educational
    gcompris        # 100+ educational activities — ages 2-10

    # Creative
    krita           # Digital painting and drawing

    # Media
    freetube        # YouTube without ads, algorithm, or shorts
  ];
}
