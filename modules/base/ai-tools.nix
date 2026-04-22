# ===========================================================================
# modules/base/ai-tools.nix — AI tools and MCP server dependencies
# ===========================================================================
{ config, pkgs, lib, ... }:

{
  options = {
    ai-tools = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable AI tools and MCP dependencies";
      };
    };
  };

  config = lib.mkIf (config.ai-tools.enable or true) {
    # Core system packages for AI tools
    environment.systemPackages = with pkgs; [
      ffmpeg              # Media processing for faster-whisper
      python3             # Python runtime for MCP servers
      uv                  # uv/uvx for running MCP servers (faster-whisper, nixos)
      openssh             # SSH access
      git                 # Git operations
      gh                  # GitHub CLI
    ];

    # nix-ld provides /lib64/ld-linux-x86-64.so.2 as a compatibility shim
    # so prebuilt Linux binaries (like opencode) can run without ELF patching.
    # Patching Bun standalone binaries with patchelf breaks them because Bun
    # uses /proc/self/exe to locate its embedded JS — patchelf shifts offsets
    # and the interpreter-invocation workaround breaks /proc/self/exe too.
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [ glibc ];
  };
}