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
# Options:
#   programs.lmStudio.enable = true;
#
# Usage:
#   1. Import modules/development/ai-tools/default.nix (nix-ld + uv + ffmpeg)
#   2. Import this module
#   3. Set programs.lmStudio.enable = true in your host config
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  options.programs.lmStudio = {
    enable = lib.mkEnableOption "LM Studio local AI model manager";
  };

  config = lib.mkIf config.programs.lmStudio.enable {

    # =========================================================================
    # LM Studio — prebuilt GUI app, requires nix-ld (ai-tools/default.nix)
    # =========================================================================
    environment.systemPackages = [ pkgs.lmstudio ];

  };
}
