# ===========================================================================
# modules/development/editors/neovim/hm.nix — Neovim (Home Manager)
#
# Config lives at dotfiles/nvim/ and is symlinked to ~/.config/nvim via an
# activation script (not home.file — programs.neovim generates init.lua which
# conflicts with home.file symlink directory management).
#
# Activation order:
#   1. preCleanNvimInitLua (before checkLinkTargets) — removes HM-generated
#      init.lua so checkLinkTargets doesn't see a stale managed file.
#   2. nvimConfig (after writeBoundary) — removes whatever HM wrote during
#      writeBoundary, then creates ~/.config/nvim → dotfiles/nvim symlink.
#
# lazy.nvim writes lazy-lock.json directly into dotfiles/nvim/ (tracked in
# git). Plugins download to ~/.local/share/nvim/lazy/ (writable, outside
# the Nix store). Matugen colors go to ~/.local/share/nvim/lua/ (untracked).
#
# LSP binaries come from Nix packages below — Mason is not used on NixOS.
# ===========================================================================

{ pkgs, lib, ... }:

{
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;
    withRuby    = false;
    withPython3 = false;
  };

  # Remove HM-generated init.lua before checkLinkTargets runs, so it doesn't
  # conflict with the symlink we create after writeBoundary.
  home.activation.preCleanNvimInitLua = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f "$HOME/.config/nvim/init.lua"
  '';

  # After all HM files are written, replace ~/.config/nvim with a symlink to
  # our own config in dotfiles/nvim/.
  home.activation.nvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    NVIM_SRC="$HOME/nixos-config/dotfiles/nvim"
    NVIM_DIR="$HOME/.config/nvim"

    # Remove old rsync directory or symlink pointing to the wrong target
    if [ -d "$NVIM_DIR" ] && [ ! -L "$NVIM_DIR" ]; then
      rm -rf "$NVIM_DIR"
    fi
    if [ -L "$NVIM_DIR" ] && [ "$(readlink "$NVIM_DIR")" != "$NVIM_SRC" ]; then
      rm "$NVIM_DIR"
    fi

    # Create symlink if not already correct
    if [ ! -e "$NVIM_DIR" ]; then
      ln -s "$NVIM_SRC" "$NVIM_DIR"
    fi
  '';

  # =========================================================================
  # LSP binaries — lua/servers/ calls vim.lsp.config() + vim.lsp.enable()
  # which look for these executables. Mason is not used for installs on NixOS.
  # =========================================================================
  home.packages = with pkgs; [
    # Nix
    nil            # nil_ls
    alejandra      # nix formatter

    # Lua
    lua-language-server  # lua_ls
    stylua               # lua formatter

    # Shell
    bash-language-server  # bashls

    # Web
    vscode-langservers-extracted  # cssls + html
    typescript-language-server    # ts_ls
    tailwindcss-language-server   # tailwindcss

    # Python
    pyright

    # C/C++
    clang-tools  # clangd

    # Hyprland config files
    hyprls

    # Treesitter needs gcc to compile parsers
    gcc

    # Snacks picker backends
    fd
    ripgrep
  ];
}
