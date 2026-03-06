# ===========================================================================
# modules/users/alex-packages.nix — System packages for alex
#
# Imported by: Alex-Desktop, Alex-Laptop
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [

    # Educational
    gcompris        # 100+ educational activities — ages 2-10

    # Creative
    krita           # Digital painting and drawing

    # Office / School
    onlyoffice-desktopeditors  # Word/Excel/PowerPoint compatible office suite
    hunspell                   # Spell checker
    hunspellDicts.en-us        # English (US) dictionary

    # Media
    freetube        # YouTube without ads, algorithm, or shorts
  ];
}
