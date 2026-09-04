-- Center screen on search jumps
vim.keymap.set("n", "n",      "nzzzv",   { desc = "Next result (centered)" })
vim.keymap.set("n", "N",      "Nzzzv",   { desc = "Prev result (centered)" })
vim.keymap.set("n", "<C-d>",  "<C-d>zz", { desc = "Half page down (centered)" })
vim.keymap.set("n", "<C-u>",  "<C-u>zz", { desc = "Half page up (centered)" })

-- Buffer navigation
vim.keymap.set("n", "<Tab>",   "<Cmd>bnext<CR>",     { desc = "Next buffer" })
vim.keymap.set("n", "<S-Tab>", "<Cmd>bprevious<CR>", { desc = "Prev buffer" })

-- Window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Window up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Splits
vim.keymap.set("n", "<leader>sv", "<Cmd>vsplit<CR>", { desc = "Split vertical" })
vim.keymap.set("n", "<leader>sh", "<Cmd>split<CR>",  { desc = "Split horizontal" })

-- Resize
vim.keymap.set("n", "<C-Up>",    "<Cmd>resize +2<CR>",          { desc = "Increase height" })
vim.keymap.set("n", "<C-Down>",  "<Cmd>resize -2<CR>",          { desc = "Decrease height" })
vim.keymap.set("n", "<C-Left>",  "<Cmd>vertical resize -2<CR>", { desc = "Decrease width" })
vim.keymap.set("n", "<C-Right>", "<Cmd>vertical resize +2<CR>", { desc = "Increase width" })

-- Better indent (stay in visual mode)
vim.keymap.set("v", "<", "<gv", { desc = "Indent left" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right" })

-- Join without moving cursor
vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines" })

-- Paste without clobbering register
vim.keymap.set("v", "p", '"_dP', { noremap = true, silent = true })

-- Save
vim.keymap.set({ "n", "i" }, "<C-s>", "<Cmd>w<CR>", { desc = "Save file" })

-- Open config
vim.keymap.set("n", "<leader>rc", "<Cmd>e ~/.config/nvim/init.lua<CR>", { desc = "Edit config" })

-- Reload config and reapply matugen theme
vim.keymap.set("n", "<leader>rr", function()
  vim.cmd.source(vim.fn.stdpath("config") .. "/init.lua")
  package.loaded["matugen"] = nil
  require("matugen").setup()
  vim.notify("Config reloaded", vim.log.levels.INFO)
end, { desc = "Reload config" })

-- Markdown
vim.keymap.set("n", "<leader>mp", "<Cmd>MarkdownPreview<CR>",       { desc = "Markdown preview" })
vim.keymap.set("n", "<leader>mt", "<Cmd>MarkdownPreviewToggle<CR>", { desc = "Toggle MD preview" })
vim.keymap.set("n", "<leader>ms", "<Cmd>MarkdownPreviewStop<CR>",   { desc = "Stop MD preview" })
