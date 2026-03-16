-- ============================================================
-- Keymaps
-- Leader = Space
-- LSP keymaps are in plugins/lsp.lua (set per-buffer in on_attach)
-- ============================================================

local map = function(mode, lhs, rhs, desc, extra)
  local opts = vim.tbl_extend("force", { noremap = true, silent = true, desc = desc }, extra or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- ─── Escape ───────────────────────────────────────────────
map("i", "jk", "<Esc>",  "Escape insert mode")
map("i", "kj", "<Esc>",  "Escape insert mode")

-- ─── File ─────────────────────────────────────────────────
map("n", "<C-s>",      "<cmd>w<cr>",              "Save file")
map("n", "<leader>w",  "<cmd>w<cr>",              "Save file")
map("n", "<leader>W",  "<cmd>wa<cr>",             "Save all files")
map("n", "<leader>q",  "<cmd>q<cr>",              "Quit")
map("n", "<leader>Q",  "<cmd>qa!<cr>",            "Quit all (force)")

-- ─── Window Navigation ────────────────────────────────────
map("n", "<C-h>", "<C-w>h", "Go to left window")
map("n", "<C-j>", "<C-w>j", "Go to lower window")
map("n", "<C-k>", "<C-w>k", "Go to upper window")
map("n", "<C-l>", "<C-w>l", "Go to right window")

-- Resize splits
map("n", "<C-Up>",    "<cmd>resize +2<cr>",          "Increase window height")
map("n", "<C-Down>",  "<cmd>resize -2<cr>",          "Decrease window height")
map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>", "Decrease window width")
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", "Increase window width")

-- ─── Splits ───────────────────────────────────────────────
map("n", "<leader>sv", "<cmd>vsplit<cr>",        "Vertical split")
map("n", "<leader>sh", "<cmd>split<cr>",         "Horizontal split")
map("n", "<leader>se", "<cmd>wincmd =<cr>",      "Equal split sizes")
map("n", "<leader>sc", "<cmd>close<cr>",         "Close split")

-- ─── Buffer Navigation ────────────────────────────────────
map("n", "<S-l>", "<cmd>bnext<cr>",     "Next buffer")
map("n", "<S-h>", "<cmd>bprevious<cr>", "Previous buffer")
map("n", "<leader>bd", "<cmd>bdelete<cr>", "Delete buffer")
map("n", "<leader>bD", "<cmd>bdelete!<cr>", "Force delete buffer")
map("n", "<leader>bo", "<cmd>%bdelete|edit#|bdelete#<cr>", "Close other buffers")

-- ─── File Explorer ────────────────────────────────────────
map("n", "<leader>e", "<cmd>Neotree toggle<cr>",  "Toggle file explorer")
map("n", "<leader>E", "<cmd>Neotree reveal<cr>",  "Reveal file in explorer")

-- ─── Movement Improvements ────────────────────────────────
-- Keep cursor centered when scrolling
map("n", "<C-d>", "<C-d>zz", "Scroll down (centered)")
map("n", "<C-u>", "<C-u>zz", "Scroll up (centered)")
-- Keep search results centered
map("n", "n", "nzzzv", "Next search result (centered)")
map("n", "N", "Nzzzv", "Prev search result (centered)")

-- ─── Visual Mode ──────────────────────────────────────────
-- Move selected lines up/down
map("v", "J", ":m '>+1<cr>gv=gv", "Move selection down")
map("v", "K", ":m '<-2<cr>gv=gv", "Move selection up")
-- Stay in indent mode
map("v", "<", "<gv", "Indent left")
map("v", ">", ">gv", "Indent right")
-- Paste without overwriting clipboard
map("v", "p", '"_dP', "Paste without clipboard overwrite")

-- ─── Search ───────────────────────────────────────────────
map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlights")

-- ─── Telescope ────────────────────────────────────────────
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>",                  "Find files")
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>",                   "Live grep")
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>",                     "Find buffers")
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>",                   "Help tags")
map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>",                    "Recent files")
map("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>",        "Document symbols")
map("n", "<leader>fS", "<cmd>Telescope lsp_workspace_symbols<cr>",       "Workspace symbols")
map("n", "<leader>fd", "<cmd>Telescope diagnostics<cr>",                 "Diagnostics")
map("n", "<leader>fc", "<cmd>Telescope commands<cr>",                    "Commands")
map("n", "<leader>fk", "<cmd>Telescope keymaps<cr>",                     "Keymaps")
map("n", "<leader>fG", "<cmd>Telescope git_commits<cr>",                 "Git commits")
map("n", "<leader>/",  "<cmd>Telescope current_buffer_fuzzy_find<cr>",   "Fuzzy find in buffer")
map("n", "<leader><leader>", "<cmd>Telescope find_files<cr>",            "Find files")

-- ─── Git ──────────────────────────────────────────────────
map("n", "<leader>gg", "<cmd>LazyGit<cr>",                  "LazyGit")
map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>",             "Diff view")
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>",    "File history")
map("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>",      "Repo history")
map("n", "<leader>gc", "<cmd>DiffviewClose<cr>",            "Close diff view")
-- Gitsigns (next/prev hunk set in gitsigns.lua on_attach)

-- ─── Diagnostics / Trouble ────────────────────────────────
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",                         "Diagnostics (all)")
map("n", "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",            "Diagnostics (buffer)")
map("n", "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>",                 "Symbols")
map("n", "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",  "LSP panel")
map("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>",                             "Location list")
map("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>",                              "Quickfix list")

-- ─── Harpoon ──────────────────────────────────────────────
map("n", "<leader>ha", function() require("harpoon"):list():add() end,    "Harpoon: add file")
map("n", "<leader>hh", function()
  local h = require("harpoon")
  h.ui:toggle_quick_menu(h:list())
end, "Harpoon: menu")
map("n", "<leader>h1", function() require("harpoon"):list():select(1) end, "Harpoon: file 1")
map("n", "<leader>h2", function() require("harpoon"):list():select(2) end, "Harpoon: file 2")
map("n", "<leader>h3", function() require("harpoon"):list():select(3) end, "Harpoon: file 3")
map("n", "<leader>h4", function() require("harpoon"):list():select(4) end, "Harpoon: file 4")

-- ─── TODOs ────────────────────────────────────────────────
map("n", "<leader>td", "<cmd>TodoTelescope<cr>", "Search TODOs")

-- ─── AI Tools ─────────────────────────────────────────────
-- Claude Code (claudecode-nvim)
map("n", "<leader>cc", "<cmd>ClaudeCode<cr>",       "Toggle Claude Code")
map("v", "<leader>cs", "<cmd>ClaudeCodeSend<cr>",   "Send selection to Claude")

-- Opencode (opencode-nvim or toggleterm fallback)
map("n", "<leader>oc", "<cmd>Opencode<cr>", "Toggle Opencode")

-- ─── Misc ─────────────────────────────────────────────────
-- Format (also set in LSP on_attach as buffer-local)
map("n", "<leader>f", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, "Format file")

-- Toggle word wrap
map("n", "<leader>tw", "<cmd>set wrap!<cr>", "Toggle word wrap")
-- Toggle spell check
map("n", "<leader>ts", "<cmd>set spell!<cr>", "Toggle spell check")
-- Toggle relative numbers
map("n", "<leader>tn", "<cmd>set relativenumber!<cr>", "Toggle relative numbers")
