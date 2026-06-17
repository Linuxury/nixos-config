# ===========================================================================
# modules/system/graphical/zennotes/default.nix — ZenNotes desktop client
#
# Keyboard-first Markdown notes with Vim motions, live math/diagrams,
# and MCP integration. Packaged as an AppImage (not in nixpkgs).
#
# After install, connect to the self-hosted server:
#   Settings → Connect to Remote Vault → http://Media-Server:7879
#   Enter the auth token from secrets/zennotes-auth-token.age
#
# Server module: modules/services/zennotes/default.nix (Media-Server)
#
# Version: 2.3.0
# ===========================================================================

{ pkgs, ... }:

let
  zennotes = pkgs.appimageTools.wrapType2 {
    pname   = "zennotes";
    version = "2.3.0";
    src     = pkgs.fetchurl {
      url  = "https://github.com/ZenNotes/zennotes/releases/download/v2.3.0/ZenNotes-2.3.0-linux-x86_64.AppImage";
      hash = "sha256-IvFGK7n3KQVGETmt6hQUy+bZNTOCkfuwH8ifl4KTxxw=";
    };
  };
in

{
  environment.systemPackages = [ zennotes ];
}
