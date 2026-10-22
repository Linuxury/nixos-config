# ===========================================================================
# modules/development/ai-tools/goose/default.nix — Goose AI agent
#
# Goose (block/goose) with Claude through the claude-acp provider: Goose drives
# the official Claude Code via the claude-agent-acp adapter, so requests come
# from Claude Code and the Claude Pro/Max subscription covers them. (Tools that
# reuse Claude's OAuth login directly, like opencode-claude-auth, get rejected.)
# Shares the subscription's usage limits with Claude Code.
#
# One-time setup per user (~/.config/goose/config.yaml is app-owned, so it's
# not managed here):
#   goose configure → Configure Providers → Claude Code → model "default" (opus)
#   Optional: Goose Settings → Goose Mode → smart_approve (ask before acting;
#   the default "auto" runs tools without asking).
#
# Requires: modules/development/ai-tools/claude/default.nix (logged-in claude)
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    goose-cli         # Goose agent CLI (goose session / goose run)
    claude-agent-acp  # ACP adapter Goose's claude-acp provider runs
  ];
}
