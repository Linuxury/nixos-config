# ===========================================================================
# modules/services/local-llm.nix — On-demand local LLM via Ollama (ROCm)
#
# Designed for AMD GPU hosts. Does NOT run a background service — you
# control it manually with fish functions:
#
#   llm-start   — start Ollama server in background
#   llm-stop    — stop Ollama server
#   llm         — open a chat session (auto-starts if needed)
#   llm-log     — tail the Ollama server log
#
# First-time setup after rebuild:
#   ollama pull qwen2.5:14b   (or whatever model you configured)
#
# Options:
#   services.localLlm.enable = true;
#   services.localLlm.user   = "linuxury";
#   services.localLlm.model  = "qwen2.5:14b";  # optional, this is the default
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  options.services.localLlm = {

    enable = lib.mkEnableOption "on-demand local LLM via Ollama with AMD ROCm";

    model = lib.mkOption {
      type        = lib.types.str;
      default     = "qwen2.5:14b";
      description = ''
        Ollama model tag to load. Must be pulled first with: ollama pull <model>

        Recommended options for your 7900 XTX (24GB VRAM):
          qwen2.5:14b   — fast (~70 TPS), great for markdown/configs  [default]
          qwen2.5:32b   — slower (~35 TPS), more capable, fits in 24GB
      '';
    };

    user = lib.mkOption {
      type        = lib.types.str;
      description = "Username to grant ROCm GPU access (added to render group).";
    };

  };

  config = lib.mkIf config.services.localLlm.enable {

    # -------------------------------------------------------------------------
    # Ollama binary — ROCm acceleration is activated at runtime via
    # HSA_OVERRIDE_GFX_VERSION. Your 7900 XTX is RDNA3 = gfx1100 = 11.0.0
    # -------------------------------------------------------------------------
    environment.systemPackages = [ pkgs.ollama ];

    # -------------------------------------------------------------------------
    # ROCm needs /dev/dri/renderD* access — that's the render group.
    # The video group (already set in your host config) covers /dev/kfd.
    # -------------------------------------------------------------------------
    users.users.${config.services.localLlm.user}.extraGroups = [ "render" ];

    # -------------------------------------------------------------------------
    # Fish functions — on-demand control, no systemd service, no sudo needed
    # -------------------------------------------------------------------------
    programs.fish.interactiveShellInit = lib.mkAfter ''
      function llm-start --description "Start Ollama LLM server in background (ROCm)"
        if pgrep -x ollama > /dev/null
          echo "Ollama is already running"
          return 0
        end
        set -x HSA_OVERRIDE_GFX_VERSION 11.0.0
        ollama serve > /tmp/ollama.log 2>&1 &
        disown
        sleep 1
        echo "Ollama started — use llm-log to watch output"
      end

      function llm-stop --description "Stop Ollama server"
        if pkill -x ollama
          echo "Ollama stopped"
        else
          echo "Ollama was not running"
        end
      end

      function llm --description "Chat with local LLM (${config.services.localLlm.model})"
        if not pgrep -x ollama > /dev/null
          echo "Starting Ollama..."
          llm-start
          sleep 2
        end
        ollama run ${config.services.localLlm.model} $argv
      end

      function llm-log --description "Tail the Ollama server log"
        tail -f /tmp/ollama.log
      end
    '';

  };
}
