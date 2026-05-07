# ===========================================================================
# modules/base/libreoffice.nix — LibreOffice office suite
#
# Imported by: Alex-Desktop, Alex-Laptop, Ryzen5800x
#
# Opt-in module — not in graphical-base because it's a heavy build
# and not every host needs a full office suite.
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    libreoffice    # Full office suite — word processor, spreadsheet, presentations, draw
    hunspell       # Spell checker backend for LibreOffice
    hunspellDicts.en-us  # English (US) dictionary
  ];
}
