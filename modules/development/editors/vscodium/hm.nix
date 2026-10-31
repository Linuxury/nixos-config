# ===========================================================================
# modules/development/editors/vscodium/hm.nix — VSCodium (Home Manager)
#
# Declarative VSCodium setup: extensions, settings, and NixOS compatibility
# patches applied on every rebuild.
#
# Settings file:
#   Base settings live in dotfiles/vscodium/settings.json (tracked in repo,
#   no secrets). On every rebuild, vscodiumSettings merges the base with the
#   flow-icons license key from agenix, writing a real (non-symlink) file so
#   VSCodium can modify it at runtime.
#
# NixOS Claude Code wrapper:
#   The extension bundles a generic Linux binary that fails on NixOS (dynamic
#   linker mismatch). vscodiumClaudeWrapper replaces it with a thin script
#   that calls the Nix-installed claude binary. Runs on every rebuild so it
#   survives extension updates automatically.
#
# Extensions not in nixpkgs are fetched from Open VSX (not VS Marketplace)
# to comply with VSCodium's ToS.
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  # =========================================================================
  # VSCodium — declarative extensions
  # =========================================================================
  programs.vscodium = {
    enable               = true;
    mutableExtensionsDir = true;

    profiles.default.extensions =
      (with pkgs.vscode-extensions; [
        catppuccin.catppuccin-vsc  # Catppuccin Mocha color theme
        golang.go                  # Go language support
      ])
      # Open VSX extensions pinned in extensions.json; update with
      # scripts/vscodium-ext-bump (run by nru on the lock writer). Entries with a
      # "hold" reason are bumped by hand. Claude Code uses the linux-x64 variant
      # because nixpkgs' version has a stale hash.
      ++ lib.mapAttrsToList (name: e: pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = { inherit name; inherit (e) publisher version; };
        vsix = pkgs.fetchurl { inherit (e) url sha256; };
      }) (builtins.fromJSON (builtins.readFile ./extensions.json));
  };

  # =========================================================================
  # Settings — generated at activation so the flow-icons license key can be
  # injected from agenix without ever touching the tracked dotfile.
  #
  # Base settings: dotfiles/vscodium/settings.json (no secrets)
  # Final file:    ~/.config/VSCodium/User/settings.json (real file, not symlink)
  # =========================================================================
  home.activation.vscodiumSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _base="$HOME/nixos-config/dotfiles/vscodium/settings.json"
    _target="$HOME/.config/VSCodium/User/settings.json"
    _license="/run/agenix/flow-icons-license"

    # Remove any existing symlink so we can write a real file
    [ -L "$_target" ] && rm "$_target"
    mkdir -p "$(dirname "$_target")"

    if [ -r "$_license" ]; then
      ${pkgs.python3}/bin/python3 -c "
import json, sys
with open('$_base') as f:
    s = json.load(f)
with open('$_license') as f:
    s['flow-icons.licenseKey'] = f.read().strip()
with open('$_target', 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
"
    else
      cp "$_base" "$_target"
    fi
  '';

  # =========================================================================
  # NixOS Claude Code wrapper
  #
  # The extension bundles a generic Linux binary that can't run on NixOS
  # (dynamic linker mismatch). This activation script replaces the bundled
  # binary with a thin wrapper that calls the Nix-installed claude binary.
  #
  # Runs on every rebuild so it survives extension updates automatically.
  # The original binary is preserved as claude.orig on first run.
  # =========================================================================
  home.activation.vscodiumClaudeWrapper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CLAUDE_REAL="/run/current-system/sw/bin/claude"
    EXT_DIR="$HOME/.vscode-oss/extensions"

    for ext_claude in "$EXT_DIR"/anthropic.claude-code-*/resources/native-binary/claude; do
      [ -e "$ext_claude" ] || continue
      # Skip Nix store paths — read-only; claudeProcessWrapper in settings.json handles NixOS
      case "$ext_claude" in /nix/store/*) continue;; esac
      # Skip if already our wrapper
      grep -q "exec $CLAUDE_REAL" "$ext_claude" 2>/dev/null && continue
      # Backup original binary once
      [ -f "$ext_claude.orig" ] || mv "$ext_claude" "$ext_claude.orig"
      [ -f "$ext_claude.orig" ] && rm -f "$ext_claude"
      printf '#!/bin/sh\nexec %s "$@"\n' "$CLAUDE_REAL" > "$ext_claude"
      chmod +x "$ext_claude"
    done
  '';
}
