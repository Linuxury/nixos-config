-- ============================================================
-- Treesitter — accurate syntax highlighting + smart text objects
-- All grammars are installed via Nix (nvim-treesitter.withAllGrammars)
-- ============================================================

require("nvim-treesitter.configs").setup({
  -- Grammars managed by Nix — do NOT let treesitter auto-install
  auto_install = false,
  sync_install  = false,
  ensure_installed = {},   -- empty: Nix handles this

  highlight = {
    enable                            = true,
    additional_vim_regex_highlighting = false,
  },

  indent = {
    enable = true,
  },

  -- Smart incremental selection (Ctrl+Space to grow, Ctrl+Backspace to shrink)
  incremental_selection = {
    enable  = true,
    keymaps = {
      init_selection    = "<C-space>",
      node_incremental  = "<C-space>",
      scope_incremental = "<C-s>",
      node_decremental  = "<bs>",
    },
  },

  -- Text objects — select/move/swap by function, class, etc.
  textobjects = {
    select = {
      enable    = true,
      lookahead = true,   -- jump to next text object if not under cursor
      keymaps   = {
        ["af"] = { query = "@function.outer", desc = "around function" },
        ["if"] = { query = "@function.inner", desc = "inner function" },
        ["ac"] = { query = "@class.outer",    desc = "around class" },
        ["ic"] = { query = "@class.inner",    desc = "inner class" },
        ["aa"] = { query = "@parameter.outer", desc = "around argument" },
        ["ia"] = { query = "@parameter.inner", desc = "inner argument" },
        ["ab"] = { query = "@block.outer",    desc = "around block" },
        ["ib"] = { query = "@block.inner",    desc = "inner block" },
        ["al"] = { query = "@loop.outer",     desc = "around loop" },
        ["il"] = { query = "@loop.inner",     desc = "inner loop" },
      },
    },
    move = {
      enable              = true,
      set_jumps           = true,
      goto_next_start     = {
        ["]f"] = { query = "@function.outer", desc = "Next function" },
        ["]c"] = { query = "@class.outer",    desc = "Next class" },
        ["]a"] = { query = "@parameter.inner", desc = "Next argument" },
      },
      goto_previous_start = {
        ["[f"] = { query = "@function.outer", desc = "Prev function" },
        ["[c"] = { query = "@class.outer",    desc = "Prev class" },
        ["[a"] = { query = "@parameter.inner", desc = "Prev argument" },
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ["<leader>na"] = "@parameter.inner",
      },
      swap_previous = {
        ["<leader>pa"] = "@parameter.inner",
      },
    },
  },
})

-- ── Treesitter Context ─────────────────────────────────────
-- Shows the current function/class at the top of the screen
require("treesitter-context").setup({
  enable            = true,
  max_lines         = 4,    -- max lines of context shown
  min_window_height = 20,
  line_numbers      = true,
  multiline_threshold = 20,
  trim_scope        = "outer",
  mode              = "cursor",
  separator         = nil,
  zindex            = 20,
})
