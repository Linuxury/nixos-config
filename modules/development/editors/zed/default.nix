# ===========================================================================
# modules/development/editors/zed/default.nix — Zed Editor
#
# Zed is a fast, Wayland-native code editor written in Rust with built-in
# LSP support, vim mode, blurred window background, and GPU rendering.
#
# Configuration:
#   dotfiles/zed/settings.json — Catppuccin Mocha theme, Material icons,
#   vim mode, blurred background, direnv integration, zsh terminal.
#
# LSP binaries are shared with Neovim — nil, alejandra, pyright, etc.
# are already on PATH when both editors are active.
# ===========================================================================

{ pkgs, ... }:

{
  # =========================================================================
  # Zed — system package (available to all users on this host)
  # =========================================================================
  environment.systemPackages = [ pkgs.zed-editor ];

  # =========================================================================
  # Home Manager — dotfile injected into every user on this host
  # =========================================================================
  home-manager.sharedModules = [
    {
      home.file.".config/zed/settings.json".source =
        ../../../dotfiles/zed/settings.json;
    }
  ];
}
