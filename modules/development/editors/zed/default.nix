# ===========================================================================
# modules/development/editors/zed/default.nix — Zed Editor
#
# Zed is a fast, Wayland-native code editor written in Rust with built-in
# LSP support, vim mode, blurred window background, and GPU rendering.
#
# Enable per host by importing this module:
#   ../../modules/development/editors/zed/default.nix
#
# Configuration is managed inside Zed itself (Settings → Open Settings).
# ===========================================================================

{ lib, pkgs, ... }:

{
  # Force OpenGL backend — avoids wgpu Vulkan surface panic on Hyprland workspace switch
  environment.sessionVariables.WGPU_BACKEND = "gl";

  # =========================================================================
  # Zed — system package (available to all users on this host)
  # =========================================================================
  environment.systemPackages = with pkgs; [
    zed-editor
    nixd        # Nix language server — required by Zed's Nix extension
  ];

  # Text editor MIME defaults — lib.mkForce wins over VSCodium (plain) and
  # Neovim (lib.mkDefault) when all three are installed on the same host.
  home-manager.sharedModules = [{
    xdg.mimeApps.defaultApplications = {
      "text/plain"                = lib.mkForce "dev.zed.Zed.desktop";
      "application/json"          = lib.mkForce "dev.zed.Zed.desktop";
      "application/x-yaml"        = lib.mkForce "dev.zed.Zed.desktop";
      "application/toml"          = lib.mkForce "dev.zed.Zed.desktop";
      "application/x-shellscript" = lib.mkForce "dev.zed.Zed.desktop";
      "text/x-shellscript"        = lib.mkForce "dev.zed.Zed.desktop";
    };
  }];
}
