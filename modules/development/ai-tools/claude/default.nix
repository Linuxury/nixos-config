# ===========================================================================
# modules/development/ai-tools/claude/default.nix — Claude Code
#
# Installs the claude-code CLI and wraps it in a bash-compat shell script
# so the binary always runs under bash (not sh), which is required because
# claude-code uses bash-specific features that break under POSIX sh.
#
# The VSCodium extension config (claudeCode.claudeProcessWrapper) in
# dotfiles/vscodium/settings.json points at this wrapper so the extension
# uses the same Nix-installed binary.
#
# Requires: modules/development/ai-tools/default.nix (nix-ld)
# ===========================================================================

{ pkgs, ... }:

{
  # =========================================================================
  # Claude Code — wrapper ensures bash is the shell, not sh
  # =========================================================================
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "claude" ''
      exec env SHELL=${pkgs.bash}/bin/bash ${pkgs.claude-code}/bin/claude "$@"
    '')
  ];
}
