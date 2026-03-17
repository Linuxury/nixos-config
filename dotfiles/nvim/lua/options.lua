-- ============================================================
-- Neovim Options
-- ============================================================

local opt = vim.opt

-- Line numbers
opt.number         = true
opt.relativenumber = true

-- Tabs & indentation (2 spaces default, LSP/treesitter overrides per filetype)
opt.tabstop        = 2
opt.shiftwidth     = 2
opt.expandtab      = true
opt.autoindent     = true
opt.smartindent    = true

-- Long line handling
opt.wrap           = false
opt.linebreak      = true        -- wrap at word boundary if wrap is on
-- opt.colorcolumn    = "80"   -- disabled: vertical ruler removed

-- Search
opt.ignorecase     = true
opt.smartcase      = true        -- case-sensitive if uppercase in pattern
opt.hlsearch       = true
opt.incsearch      = true

-- Cursor & scroll
opt.cursorline     = true
opt.scrolloff      = 8           -- lines above/below cursor before scroll
opt.sidescrolloff  = 8

-- Appearance
opt.termguicolors  = true
opt.signcolumn     = "yes"       -- always show gutter (avoids layout shifts)
opt.showmode       = false       -- lualine shows mode instead
opt.laststatus     = 3           -- single global status bar

-- Split behavior
opt.splitright     = true        -- vsplit opens right
opt.splitbelow     = true        -- split opens below

-- File handling
opt.swapfile       = false
opt.backup         = false
opt.undofile       = true
opt.undodir        = vim.fn.expand("~/.local/state/nvim/undo")

-- Performance
opt.updatetime     = 250         -- faster CursorHold (gitsigns, LSP)
opt.timeoutlen     = 300         -- faster which-key popup

-- Clipboard — use system clipboard
opt.clipboard      = "unnamedplus"

-- Mouse
opt.mouse          = "a"

-- Completion
opt.completeopt    = "menu,menuone,noselect"

-- Folds via treesitter (disabled by default, open with zR)
opt.foldmethod     = "expr"
opt.foldexpr       = "nvim_treesitter#foldexpr()"
opt.foldenable     = false
opt.foldlevel      = 99

-- Concealing (Markdown, JSON)
opt.conceallevel   = 2

-- Popup blend (matches kitty background_opacity 0.85)
opt.pumblend       = 15
opt.winblend       = 15

-- Disable netrw (using neo-tree)
vim.g.loaded_netrw       = 1
vim.g.loaded_netrwPlugin = 1

-- Leader key (set before plugins load)
vim.g.mapleader      = " "
vim.g.maplocalleader = " "
