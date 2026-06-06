# ===========================================================================
# modules/development/ai-tools/lm-studio/default.nix — LM Studio
#
# LM Studio is a GUI application for discovering, downloading, and running
# local large language models (LLaMA, Mistral, Qwen, etc.) with a chat UI
# and an OpenAI-compatible local API server.
#
# Requires: modules/development/ai-tools/default.nix (nix-ld)
# LM Studio ships as a prebuilt binary — nix-ld must be enabled for it to run.
#
# Enable per host by importing this module alongside ai-tools/default.nix:
#   ../../modules/development/ai-tools/default.nix
#   ../../modules/development/ai-tools/lm-studio/default.nix
# ===========================================================================

{ pkgs, ... }:

{
  # =========================================================================
  # LM Studio — prebuilt GUI app, requires nix-ld (ai-tools/default.nix)
  # =========================================================================
  environment.systemPackages = [ pkgs.lmstudio ];
}
