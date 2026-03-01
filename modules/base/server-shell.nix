# ===========================================================================
# modules/base/server-shell.nix — Fish shell config for headless servers
#
# Provides the same NixOS aliases as desktop hosts (nr, nru, nrb, etc.)
# but WITHOUT the desktop-only tools:
#   - fastfetch   (graphical eye candy — not useful over SSH)
#   - starship    (prompt — fish's built-in is fine for servers)
#   - zoxide      (smarter cd — not installed on servers)
#   - snapper     (BTRFS snapshots — servers don't import snapper.nix)
#
# Writes to /etc/fish/config.fish (system-level), so it applies to ALL
# users on the machine without needing Home Manager.
#
# Import this in: Radxa-X4, MinisForum, Media-Server (any headless host).
# ===========================================================================

{ lib, ... }:

{
  programs.fish.shellInit = lib.fileContents ../../dotfiles/fish/config-server.fish;
}
