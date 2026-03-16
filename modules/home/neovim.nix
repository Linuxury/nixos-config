# ===========================================================================
# modules/home/neovim.nix — Neovim Home Manager module (all users)
#
# Provides a full IDE-like Neovim setup with:
#   - Plugins managed by Nix (pre-built, no lazy.nvim downloads)
#   - Lua config from dotfiles/nvim/ (symlinked)
#   - LSP servers + formatters installed as Nix packages
#   - Matugen colorscheme (auto-generated from wallpaper)
#   - Native claude-code and opencode integrations
#
# Import this in each user's home.nix:
#   imports = [ ../../modules/home/neovim.nix ];
#
# linuxury override (live config editing without rebuild):
#   xdg.configFile."nvim/init.lua" = lib.mkForce { source = config.lib.file.mkOutOfStoreSymlink "..."; };
#   xdg.configFile."nvim/lua"      = lib.mkForce { source = config.lib.file.mkOutOfStoreSymlink "..."; };
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  # Naruto chibi image — embedded in Nix store so all users can access it
  # regardless of home directory. Path passed to neovim via vim.g.naruto_image_path
  narutoImage = ../../assets/Fastfetch/naruto-chibi-3.png;

in
{
  # =========================================================================
  # Neovim — program config
  # =========================================================================
  programs.neovim = {
    enable        = true;
    defaultEditor = true;    # sets $EDITOR and $VISUAL
    viAlias       = true;    # vi  → nvim
    vimAlias      = true;    # vim → nvim


    plugins = with pkgs.vimPlugins; [
      # ── Dependencies ─────────────────────────────────────────
      plenary-nvim          # utility lib used by many plugins
      nui-nvim              # UI component lib (noice, neo-tree)
      nvim-web-devicons     # file/folder icons

      # ── UI & Layout ──────────────────────────────────────────
      neo-tree-nvim         # file explorer sidebar
      lualine-nvim          # status bar
      bufferline-nvim       # tab bar
      indent-blankline-nvim # indent guide lines
      noice-nvim            # fancy cmdline / messages UI
      nvim-notify           # notification popups
      dashboard-nvim        # startup screen
      dressing-nvim         # prettier select/input dialogs
      nvim-scrollbar        # scrollbar with git/diagnostic marks
      fidget-nvim           # LSP loading spinner
      trouble-nvim          # diagnostics panel
      todo-comments-nvim    # TODO/FIXME highlights
      which-key-nvim        # keybinding popup helper

      # ── Syntax & Treesitter ──────────────────────────────────
      (nvim-treesitter.withAllGrammars)  # all language grammars
      nvim-treesitter-textobjects        # select/move by function/class
      nvim-treesitter-context            # sticky function context header

      # ── LSP ──────────────────────────────────────────────────
      nvim-lspconfig        # LSP client configuration

      # ── Completion ───────────────────────────────────────────
      nvim-cmp              # completion engine
      cmp-nvim-lsp          # LSP completions source
      cmp-buffer            # buffer words source
      cmp-path              # file path source
      cmp-cmdline           # command-line completions
      luasnip               # snippet engine
      cmp_luasnip           # luasnip source for cmp
      friendly-snippets     # VSCode-style snippets for all languages
      lspkind-nvim          # icons in completion menu

      # ── Git ──────────────────────────────────────────────────
      gitsigns-nvim         # git status gutter + inline blame
      lazygit-nvim          # lazygit floating window
      diffview-nvim         # side-by-side diffs + file history

      # ── Search & Navigation ───────────────────────────────────
      telescope-nvim             # fuzzy finder
      telescope-fzf-native-nvim  # faster fzf sorting for telescope

      # ── Quick navigation ─────────────────────────────────────
      harpoon2              # pin hot files for instant switching
      flash-nvim            # jump anywhere in 2 keystrokes

      # ── Editing helpers ───────────────────────────────────────
      nvim-autopairs        # auto-close brackets/quotes
      comment-nvim          # gcc/gc to toggle comments
      nvim-surround         # add/change/delete surrounding chars
      nvim-ts-autotag       # auto-close HTML/JSX tags

      # ── Formatting & Linting ─────────────────────────────────
      conform-nvim          # format on save
      nvim-lint             # async linting

      # ── Terminal & AI ─────────────────────────────────────────
      toggleterm-nvim       # persistent floating terminal
      claudecode-nvim       # native claude-code side panel
      opencode-nvim         # native opencode side panel

      # ── Images ───────────────────────────────────────────────
      image-nvim            # render images (kitty protocol — works in ghostty)
    ];
  };

  # =========================================================================
  # Neovim lua config — linked from dotfiles/nvim/
  #
  # init.lua and the lua/ directory are symlinked from the Nix store.
  # The colors/ directory is NOT managed here — matugen writes to it directly.
  #
  # linuxury can override these with mkOutOfStoreSymlink for live editing.
  # =========================================================================
  xdg.configFile."nvim/init.lua" = {
    source = ../../dotfiles/nvim/init.lua;
  };

  xdg.configFile."nvim/lua" = {
    source    = ../../dotfiles/nvim/lua;
    recursive = false;  # link the whole directory, not individual files
  };

  # Nix-injected runtime values (image paths, store paths, etc.)
  # Written separately so it doesn't conflict with the lua/ directory symlink.
  # Loaded at the top of init.lua via: dofile(vim.fn.stdpath("config").."/nix-paths.lua")
  xdg.configFile."nvim/nix-paths.lua".text = ''
    -- Auto-generated by Nix — do not edit (regenerated on rebuild)
    vim.g.naruto_image_path = "${narutoImage}"
  '';

  # =========================================================================
  # Ensure ~/.config/nvim/colors/ exists for matugen to write into
  # Also create a placeholder matugen.lua so neovim doesn't error on
  # first boot before matugen has run.
  # =========================================================================
  home.activation.nvimColors = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    COLORS_DIR="$HOME/.config/nvim/colors"
    COLORS_FILE="$COLORS_DIR/matugen.lua"

    mkdir -p "$COLORS_DIR"

    if [ ! -f "$COLORS_FILE" ]; then
      cat > "$COLORS_FILE" << 'EOF'
-- Placeholder: run your wallpaper slideshow to generate matugen colors.
-- This file is regenerated on every wallpaper change.
vim.cmd("highlight clear")
vim.g.colors_name = "matugen"
EOF
      echo "nvim: created placeholder matugen colorscheme at $COLORS_FILE"
    fi
  '';

  # =========================================================================
  # LSP servers — installed as Nix packages (no mason needed)
  # Formatters and linters are also here so conform.nvim and nvim-lint
  # can call them from $PATH.
  # =========================================================================
  home.packages = with pkgs; [
    # ── LSP servers ───────────────────────────────────────────
    lua-language-server             # Lua
    nil                             # Nix
    bash-language-server            # Bash / Shell
    typescript-language-server      # TypeScript / JavaScript
    pyright                         # Python (type checking)
    rust-analyzer                   # Rust
    marksman                        # Markdown
    yaml-language-server            # YAML
    taplo                           # TOML
    clang-tools                     # C / C++ (includes clangd)

    # ── Formatters ────────────────────────────────────────────
    stylua                          # Lua formatter
    alejandra                       # Nix formatter
    ruff                            # Python linter + formatter
    nodePackages.prettier           # JS/TS/JSON/YAML/Markdown
    shfmt                           # Shell formatter
    rustfmt                         # Rust formatter

    # ── Linters ───────────────────────────────────────────────
    shellcheck                      # Shell linter
    statix                          # Nix linter
    markdownlint-cli                # Markdown linter
    yamllint                        # YAML linter

    # ── AI tools ──────────────────────────────────────────────
    opencode                        # Opencode AI coding assistant
    # claude-code is installed separately (already in linuxury's packages)

    # ── Git ───────────────────────────────────────────────────
    lazygit                         # TUI git client (used by lazygit-nvim)

    # ── Image rendering (image.nvim dependency) ───────────────
    # imagemagick is already in wallpaper-slideshow.nix for matugen
    # but include here as fallback for users without slideshow
    imagemagick
  ];
}
