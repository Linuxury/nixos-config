-- ============================================================
-- Terminal Integration
-- ── claudecode-nvim: native Claude Code side panel
-- ── opencode-nvim:  native Opencode side panel
-- ── toggleterm:     floating terminal for quick shell use
-- ============================================================

-- ── Claude Code ───────────────────────────────────────────
require("claudecode").setup({
  -- Terminal splits to the right like the screenshot
  split_side             = "right",
  split_width_percentage = 0.38,
  -- Syncs the file you're editing in neovim with Claude
  auto_close_on_leave    = false,
  -- Use the claude binary (installed system-wide via Nix)
  terminal_cmd           = nil,   -- auto-detected
})

-- ── Opencode ──────────────────────────────────────────────
-- opencode-nvim provides a side panel similar to claudecode-nvim
local ok_oc, opencode = pcall(require, "opencode")
if ok_oc and type(opencode) == "table" and opencode.setup then
  opencode.setup({
    split_direction        = "right",
    split_size             = 0.38,
  })
end

-- ── Toggleterm — floating terminal ────────────────────────
require("toggleterm").setup({
  size = function(term)
    if term.direction == "horizontal" then
      return 12
    elseif term.direction == "vertical" then
      return vim.o.columns * 0.4
    end
  end,
  open_mapping       = [[<C-\>]],
  hide_numbers       = true,
  shade_filetypes    = {},
  autochdir          = false,
  shade_terminals    = false,
  start_in_insert    = true,
  insert_mappings    = true,
  terminal_mappings  = true,
  persist_size       = true,
  persist_mode       = true,
  direction          = "horizontal",
  close_on_exit      = true,
  shell              = vim.o.shell,
  auto_scroll        = true,
  float_opts         = {
    border   = "curved",
    winblend = 5,
  },
  winbar = {
    enabled      = false,
    name_formatter = function(term)
      return term.name
    end,
  },
})

-- Close toggleterm with <Esc> or q when in terminal mode
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "term://*toggleterm#*",
  callback = function()
    local opts = { buffer = 0, noremap = true, silent = true }
    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], opts)
    vim.keymap.set("t", "q",     [[<C-\><C-n><cmd>close<cr>]], opts)
    vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], opts)
    vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], opts)
    vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], opts)
    vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], opts)
  end,
})
