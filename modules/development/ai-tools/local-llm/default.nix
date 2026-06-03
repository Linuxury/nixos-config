# ===========================================================================
# modules/development/ai-tools/local-llm/default.nix — On-demand local LLM
#
# Runs Ollama with AMD ROCm GPU acceleration. Designed as on-demand rather
# than a persistent background service — use the zsh functions below to
# control it manually so it only uses VRAM when you actually need it.
#
# Zsh shell functions:
#   llm-start   — start Ollama server in background (sets ROCm env vars)
#   llm-stop    — stop Ollama server
#   llm         — open a chat session (auto-starts server if needed)
#   llm-log     — tail the Ollama server log
#
# Hardware requirement: AMD GPU with ROCm support (RDNA2+)
#
# First-time setup after rebuild:
#   ollama pull <model>
#
# Options:
#   services.localLlm.enable     = true;
#   services.localLlm.user       = "yourusername";
#   services.localLlm.model      = "qwen2.5:14b";    # default
#   services.localLlm.gfxVersion = "11.0.0";         # ROCm GFX override
#
# Finding your gfxVersion:
#   rocminfo | grep 'gfx'   → e.g. gfx1100 = "11.0.0", gfx1030 = "10.3.0"
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  options.services.localLlm = {

    enable = lib.mkEnableOption "on-demand local LLM via Ollama with AMD ROCm";

    user = lib.mkOption {
      type        = lib.types.str;
      description = "Username to grant ROCm GPU access (added to render group).";
    };

    model = lib.mkOption {
      type        = lib.types.str;
      default     = "qwen2.5:14b";
      description = ''
        Ollama model tag to load. Must be pulled first with: ollama pull <model>

        Examples by VRAM:
          qwen2.5:7b    — fits in 8 GB VRAM,  fast
          qwen2.5:14b   — fits in 12 GB VRAM, good balance  [default]
          qwen2.5:32b   — fits in 24 GB VRAM, most capable
      '';
    };

    gfxVersion = lib.mkOption {
      type        = lib.types.str;
      default     = "11.0.0";
      description = ''
        HSA_OVERRIDE_GFX_VERSION value for your AMD GPU.
        Tells ROCm which GFX target to use for your GPU generation.

        Common values:
          "10.3.0"  — RDNA2 (RX 6000 series)
          "11.0.0"  — RDNA3 (RX 7000 series)  [default]
          "9.0.0"   — Vega / Navi 10

        Find yours: rocminfo | grep gfx
      '';
    };

  };

  config = lib.mkIf config.services.localLlm.enable {

    # -------------------------------------------------------------------------
    # Ollama binary — ROCm build required for AMD GPU acceleration.
    # pkgs.ollama is CPU-only; pkgs.ollama-rocm compiles in HIP/ROCm support.
    # -------------------------------------------------------------------------
    environment.systemPackages = [ pkgs.ollama-rocm ];

    # -------------------------------------------------------------------------
    # ROCm needs /dev/dri/renderD* access — that is the render group.
    # The video group (set in the host config) covers /dev/kfd.
    # -------------------------------------------------------------------------
    users.users.${config.services.localLlm.user}.extraGroups = [ "render" ];

    # -------------------------------------------------------------------------
    # Zsh shell functions — on-demand control, no systemd service, no sudo
    # -------------------------------------------------------------------------
    programs.zsh.interactiveShellInit = lib.mkAfter ''
      llm-start() {
        if pgrep -x ollama > /dev/null; then
          echo "Ollama is already running"
          return 0
        fi
        export HSA_OVERRIDE_GFX_VERSION=${config.services.localLlm.gfxVersion}
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
