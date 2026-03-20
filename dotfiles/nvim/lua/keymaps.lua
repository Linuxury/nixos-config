-- Leader = Space (set in options.lua)

local map = function(mode, lhs, rhs, desc, extra)
  local opts = vim.tbl_extend("force", { noremap = true, silent = true, desc = desc }, extra or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- ── Escape ────────────────────────────────────────────────
map("i", "jk", "<Esc>", "Escape insert mode")
map("i", "kj", "<Esc>", "Escape insert mode")

-- ── File ──────────────────────────────────────────────────
map("n", "<C-s>",     "<cmd>w<cr>",   "Save file")
map("n", "<leader>w", "<cmd>w<cr>",   "Save file")
map("n", "<leader>W", "<cmd>wa<cr>",  "Save all")
map("n", "<leader>q", "<cmd>q<cr>",   "Quit")
map("n", "<leader>Q", "<cmd>qa!<cr>", "Quit all (force)")

-- ── Window Navigation ─────────────────────────────────────
map("n", "<C-h>", "<C-w>h", "Go to left window")
map("n", "<C-j>", "<C-w>j", "Go to lower window")
map("n", "<C-k>", "<C-w>k", "Go to upper window")
map("n", "<C-l>", "<C-w>l", "Go to right window")
-- Also works from terminal mode (Claude Code panel)
map("t", "<C-h>", "<C-\\><C-n><C-w>h", "Go to left window (terminal)")
map("t", "<C-j>", "<C-\\><C-n><C-w>j", "Go to lower window (terminal)")
map("t", "<C-k>", "<C-\\><C-n><C-w>k", "Go to upper window (terminal)")
map("t", "<C-l>", "<C-\\><C-n><C-w>l", "Go to right window (terminal)")

-- Resize splits
map("n", "<C-Up>",    "<cmd>resize +2<cr>",          "Increase window height")
map("n", "<C-Down>",  "<cmd>resize -2<cr>",           "Decrease window height")
map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>",  "Decrease window width")
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>",  "Increase window width")

-- ── Splits ────────────────────────────────────────────────
map("n", "<leader>sv", "<cmd>vsplit<cr>",   "Vertical split")
map("n", "<leader>sh", "<cmd>split<cr>",    "Horizontal split")
map("n", "<leader>se", "<cmd>wincmd =<cr>", "Equal split sizes")
map("n", "<leader>sc", "<cmd>close<cr>",    "Close split")

-- ── Buffer Navigation ─────────────────────────────────────
map("n", "<S-l>",      "<cmd>bnext<cr>",                              "Next buffer")
map("n", "<S-h>",      "<cmd>bprevious<cr>",                          "Previous buffer")
map("n", "<leader>bd", "<cmd>bdelete<cr>",                            "Delete buffer")
map("n", "<leader>bD", "<cmd>bdelete!<cr>",                           "Force delete buffer")
map("n", "<leader>bo", "<cmd>%bdelete|edit#|bdelete#<cr>",            "Close other buffers")

-- ── Movement ──────────────────────────────────────────────
map("n", "<C-d>", "<C-d>zz",  "Scroll down (centered)")
map("n", "<C-u>", "<C-u>zz",  "Scroll up (centered)")
map("n", "n",     "nzzzv",    "Next search result (centered)")
map("n", "N",     "Nzzzv",    "Prev search result (centered)")

-- ── Visual Mode ───────────────────────────────────────────
map("v", "J", ":m '>+1<cr>gv=gv", "Move selection down")
map("v", "K", ":m '<-2<cr>gv=gv", "Move selection up")
map("v", "<", "<gv",               "Indent left")
map("v", ">", ">gv",               "Indent right")
map("v", "p", '"_dP',              "Paste without clipboard overwrite")

-- ── Search ────────────────────────────────────────────────
map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlights")

-- ── Telescope ─────────────────────────────────────────────
map("n", "<leader><leader>", "<cmd>Telescope find_files<cr>",               "Find files")
map("n", "<leader>ff",       "<cmd>Telescope find_files<cr>",               "Find files")
map("n", "<leader>fg",       "<cmd>Telescope live_grep<cr>",                "Live grep")
map("n", "<leader>fb",       "<cmd>Telescope buffers<cr>",                  "Find buffers")
map("n", "<leader>fr",       "<cmd>Telescope oldfiles<cr>",                 "Recent files")
map("n", "<leader>fh",       "<cmd>Telescope help_tags<cr>",                "Help tags")
map("n", "<leader>fs",       "<cmd>Telescope lsp_document_symbols<cr>",     "Document symbols")
map("n", "<leader>fd",       "<cmd>Telescope diagnostics<cr>",              "Diagnostics")
map("n", "<leader>fk",       "<cmd>Telescope keymaps<cr>",                  "Keymaps")
map("n", "<leader>/",        "<cmd>Telescope current_buffer_fuzzy_find<cr>","Fuzzy find in buffer")

-- ── File Explorer ─────────────────────────────────────────
map("n", "<leader>e", function()
  if vim.g.layout_active then
    vim.cmd("Neotree toggle")
    vim.cmd("ClaudeCode")
    vim.g.layout_active = false
  else
    vim.cmd("Neotree show")
    vim.cmd("ClaudeCode")
    vim.g.layout_active = true
  end
end, "Toggle 3-column layout")
map("n", "<leader>E",  "<cmd>Neotree reveal<cr>",  "Reveal file in explorer")

-- ── AI ────────────────────────────────────────────────────
map("n", "<leader>cc", "<cmd>ClaudeCode<cr>",      "Toggle Claude Code")
map("v", "<leader>cs", "<cmd>ClaudeCodeSend<cr>",  "Send selection to Claude")

-- ── Layout ────────────────────────────────────────────────
map("n", "<leader>L", function()
  vim.cmd("Neotree show")
  vim.cmd("ClaudeCode")
  vim.g.layout_active = true
end, "Full 3-column layout")

-- ── Misc ──────────────────────────────────────────────────
map("n", "<leader>tw", "<cmd>set wrap!<cr>",         "Toggle word wrap")
map("n", "<leader>ts", "<cmd>set spell!<cr>",        "Toggle spell check")
map("n", "<leader>tn", "<cmd>set relativenumber!<cr>","Toggle relative numbers")
