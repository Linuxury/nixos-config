# ===========================================================================
# modules/development/ai-tools/default.nix — AI tools base infrastructure
#
# Provides the runtime plumbing that claude, opencode, and odysseus depend on.
# Import this alongside any AI tool module.
#
#   nix-ld   — compatibility shim so prebuilt Linux binaries (claude-code)
#               can run on NixOS without ELF patching.
#   uv       — runs Python-based MCP servers via `uvx` without a global venv.
#   ffmpeg   — required by the faster-whisper MCP server for audio processing.
# ===========================================================================

{ pkgs, ... }:

{
  # =========================================================================
  # nix-ld — dynamic linker compatibility for prebuilt binaries
  # =========================================================================
  programs.nix-ld = {
    enable    = true;
    libraries = with pkgs; [ glibc ];
  };

  # =========================================================================
  # MCP server runtime dependencies
  # =========================================================================
  environment.systemPackages = with pkgs; [
    uv      # uvx runner for Python MCP servers — no venv management needed
    ffmpeg  # audio processing for the faster-whisper MCP server
  ];
}
