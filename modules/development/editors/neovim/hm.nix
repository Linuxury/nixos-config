# ===========================================================================
# modules/development/editors/neovim/hm.nix — Neovim (Home Manager)
#
# Config lives at dotfiles/nvim/ and is symlinked to ~/.config/nvim via an
# activation script. We use home.packages for the binary instead of
# programs.neovim so HM never generates an init.lua that conflicts with our
# dotfiles symlink.
#
# lazy.nvim writes lazy-lock.json directly into dotfiles/nvim/ (tracked in
# git). Plugins download to ~/.local/share/nvim/lazy/ (writable, outside
# the Nix store). Matugen colors go to ~/.local/share/nvim/lua/ (untracked).
#
# LSP binaries come from Nix packages below — Mason is not used on NixOS.
# ===========================================================================

{ pkgs, lib, ... }:

{
  home.sessionVariables.EDITOR = "nvim";
  home.shellAliases = { vi = "nvim"; vim = "nvim"; };

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
    neovim

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
