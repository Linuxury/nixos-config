# ===========================================================================
# modules/system/graphical/claude-desktop/default.nix — Claude Desktop
#
# Official Linux beta, packaged from Anthropic's own .deb in
# pkgs/claude-desktop/package.nix (version + hash live there).
# Sign-in needs a Secret Service; Hyprland/Niri/Umbriel/COSMIC already
# enable gnome-keyring.
#
# Overlay is scoped here, so only hosts importing this module fetch it.
#
# Vault MCP (linuxury only): a filesystem MCP server named "vault" is merged
# into ~/.config/Claude/claude_desktop_config.json so Chat can read the live
# rules and vault: ~/Jarvis, ~/.agents/Shared (AGENTS.md) and
# ~/.agents/memory. Not the rest of ~/.agents: ~/.agents/Claude holds Claude
# Code's settings.json, which Chat must not be able to edit.
# ===========================================================================

{ lib, pkgs, ... }:

let
  home = "/home/linuxury";
  vaultServer = pkgs.writeText "vault-mcp-server.json" (builtins.toJSON {
    command = lib.getExe pkgs.mcp-server-filesystem;
    args = [ "${home}/Jarvis" "${home}/.agents/Shared" "${home}/.agents/memory" ];
  });
in
{
  nixpkgs.overlays = [
    (final: prev: {
      claude-desktop = prev.callPackage ../../../../pkgs/claude-desktop/package.nix {};
    })
  ];

  environment.systemPackages = [ pkgs.claude-desktop ];

  # Same merge as registerCraftMcp (craft-apps): only the "vault" key is
  # replaced, every other server is kept, and the write lands via tmp + mv.
  home-manager.users.linuxury = { lib, ... }: {
    home.activation.registerVaultMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${home}/.config/Claude"
      _cfg="${home}/.config/Claude/claude_desktop_config.json"
      _cur=$(cat "$_cfg" 2>/dev/null || printf '{}')
      if _new=$(printf '%s' "$_cur" | ${lib.getExe pkgs.jq} \
          --slurpfile s ${vaultServer} '.mcpServers = ((.mcpServers // {}) + { vault: $s[0] })'); then
        if [ "$_new" != "$_cur" ]; then
          printf '%s\n' "$_new" | run tee "$_cfg.hm-tmp" > /dev/null
          run mv "$_cfg.hm-tmp" "$_cfg"
        fi
      else
        warnEcho "registerVaultMcp: $_cfg is not valid JSON; left untouched"
      fi
      unset _cfg _cur _new
    '';
  };
}
