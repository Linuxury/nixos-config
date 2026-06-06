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

{ pkgs, ... }:

{
  # =========================================================================
  # Zed — system package (available to all users on this host)
  # =========================================================================
  environment.systemPackages = [ pkgs.zed-editor ];
}
