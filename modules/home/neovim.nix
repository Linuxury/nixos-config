# ===========================================================================
# modules/home/neovim.nix — Neovim Home Manager module (all users)
#
# Minimal IDE setup: treesitter, telescope, LSP (lua+nix), completion, gitsigns, lualine.
# Plugins managed by Nix (no lazy.nvim). Config from dotfiles/nvim/ (symlinked).
#
# linuxury override (live config editing without rebuild):
#   xdg.configFile."nvim/init.lua" = lib.mkForce { source = config.lib.file.mkOutOfStoreSymlink "..."; };
#   xdg.configFile."nvim/lua"      = lib.mkForce { source = config.lib.file.mkOutOfStoreSymlink "..."; };
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;

    plugins = with pkgs.vimPlugins; [
      # ── Dependencies ─────────────────────────────────────────
      plenary-nvim
      nui-nvim
      nvim-web-devicons

      # ── Syntax ───────────────────────────────────────────────
      (nvim-treesitter.withAllGrammars)

      # ── LSP ──────────────────────────────────────────────────
      nvim-lspconfig

      # ── Completion ───────────────────────────────────────────
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      cmp_luasnip

      # ── Git ──────────────────────────────────────────────────
      gitsigns-nvim

      # ── Search ───────────────────────────────────────────────
      telescope-nvim
      telescope-fzf-native-nvim

      # ── File explorer ─────────────────────────────────────────
      neo-tree-nvim

      # ── AI ───────────────────────────────────────────────────
      claudecode-nvim

      # ── Notes ────────────────────────────────────────────────
      obsidian-nvim

      # ── UI ───────────────────────────────────────────────────
      lualine-nvim
      bufferline-nvim
      which-key-nvim
      dashboard-nvim
    ];
  };

  # Lua config — symlinked from dotfiles/nvim/
  xdg.configFile."nvim/init.lua" = {
    source = ../../dotfiles/nvim/init.lua;
  };

  xdg.configFile."nvim/lua" = {
    source    = ../../dotfiles/nvim/lua;
    recursive = false;
  };

  # LSP servers + formatters + search tools
  home.packages = with pkgs; [
    # LSP
    lua-language-server
    nil

    # Formatters
    stylua
    alejandra

    # Telescope backends
    fd
    ripgrep
  ];
}
