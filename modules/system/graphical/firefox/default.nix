# ===========================================================================
# modules/system/graphical/firefox/default.nix — Firefox
#
# Installs Firefox with no managed policies — pure out-of-box experience.
# Imported per-host via the host imports list.
# ===========================================================================

{ ... }:

{
  programs.firefox.enable = true;
}
