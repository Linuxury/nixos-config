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
      openssh             # SSH access
      git                 # Git operations
      gh                  # GitHub CLI
    ];
  };
}