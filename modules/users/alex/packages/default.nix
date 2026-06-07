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
    # krita        # Disabled: cmake 4.1.x SIGILL on Alex-Desktop (old CPU, x86-64-v2 baseline)

    # Media
    freetube        # YouTube without ads, algorithm, or shorts
  ];
}
