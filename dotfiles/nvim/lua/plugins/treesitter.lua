-- ============================================================
-- Treesitter — accurate syntax highlighting + smart text objects
-- nvim-treesitter 0.10.x: highlight/indent are built into neovim
-- Grammars are installed via Nix (nvim-treesitter.withAllGrammars)
-- ============================================================

-- Minimal setup — just tell treesitter Nix handles installation
require("nvim-treesitter").setup({})

-- ── Treesitter Textobjects ──────────────────────────────────
-- Configured via its own plugin (nvim-treesitter-textobjects)
require("nvim-treesitter-textobjects").setup({
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
    enable    = true,
    set_jumps = true,
    goto_next_start = {
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
    swap_next     = { ["<leader>na"] = "@parameter.inner" },
    swap_previous = { ["<leader>pa"] = "@parameter.inner" },
  },
})

-- ── Treesitter Context ─────────────────────────────────────
-- Shows the current function/class at the top of the screen
require("treesitter-context").setup({
  enable            = true,
  max_lines         = 4,
  min_window_height = 20,
  line_numbers      = true,
  multiline_threshold = 20,
  trim_scope        = "outer",
  mode              = "cursor",
  separator         = nil,
  zindex            = 20,
})
