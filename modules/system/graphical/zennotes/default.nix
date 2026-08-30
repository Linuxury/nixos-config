# ===========================================================================
# modules/system/graphical/zennotes/default.nix — ZenNotes desktop client
#
# Keyboard-first Markdown notes with Vim motions, live math/diagrams,
# and MCP integration. Landed in nixpkgs as `zennotes-desktop` — ships its
# own .desktop entry, icon, and MIME associations, so nothing else is needed
# here (previously an AppImage requiring a manual desktop-entry workaround).
#
# After install, connect to the self-hosted server:
#   Settings → Connect to Remote Vault → http://Media-Server:7879
#   Enter the auth token from secrets/zennotes-auth-token.age
#
# Server module: modules/services/zennotes/default.nix (Media-Server)
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.zennotes-desktop ];
}
