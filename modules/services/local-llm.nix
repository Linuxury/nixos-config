# ===========================================================================
# modules/services/local-llm.nix — On-demand local LLM via Ollama (ROCm)
#
# Designed for AMD GPU hosts. Does NOT run a background service — you
# control it manually with zsh functions:
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
    # Ollama binary — ROCm build required for AMD GPU acceleration.
    # pkgs.ollama is CPU-only; pkgs.ollama-rocm compiles in HIP/ROCm support.
    # HSA_OVERRIDE_GFX_VERSION tells ROCm to treat your 7900 XTX (gfx1100)
    # as a fully supported target (RDNA3 = 11.0.0).
    # -------------------------------------------------------------------------
    environment.systemPackages = [ pkgs.ollama-rocm ];

    # -------------------------------------------------------------------------
    # ROCm needs /dev/dri/renderD* access — that's the render group.
    # The video group (already set in your host config) covers /dev/kfd.
    # -------------------------------------------------------------------------
    users.users.${config.services.localLlm.user}.extraGroups = [ "render" ];

    # -------------------------------------------------------------------------
    # Zsh functions — on-demand control, no systemd service, no sudo needed
    # -------------------------------------------------------------------------
    programs.zsh.interactiveShellInit = lib.mkAfter ''
      llm-start() {
        if pgrep -x ollama > /dev/null; then
          echo "Ollama is already running"
          return 0
        fi
        export HSA_OVERRIDE_GFX_VERSION=11.0.0
        ollama serve > /tmp/ollama.log 2>&1 &
        disown
        sleep 1
        echo "Ollama started — use llm-log to watch output"
      }

      llm-stop() {
        if pkill -x ollama; then
          echo "Ollama stopped"
        else
          echo "Ollama was not running"
        fi
      }

      llm() {
        if ! pgrep -x ollama > /dev/null; then
          echo "Starting Ollama..."
          llm-start
          sleep 2
        fi
        ollama run ${config.services.localLlm.model} "$@"
      }

      llm-log() {
        tail -f /tmp/ollama.log
      }
    '';

  };
}
