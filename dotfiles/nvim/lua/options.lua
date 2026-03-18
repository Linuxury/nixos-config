local opt = vim.opt

-- Leader key (set before plugins load)
vim.g.mapleader      = " "
vim.g.maplocalleader = " "

-- Line numbers
opt.number         = true
opt.relativenumber = true

-- Tabs & indentation
opt.tabstop    = 2
opt.shiftwidth = 2
opt.expandtab  = true
opt.autoindent = true
opt.smartindent = true

-- Long lines
opt.wrap      = false
opt.linebreak = true

-- Search
opt.ignorecase = true
opt.smartcase  = true
opt.hlsearch   = true
opt.incsearch  = true

-- Cursor & scroll
opt.cursorline  = true
opt.scrolloff   = 8
opt.sidescrolloff = 8

-- Appearance
opt.termguicolors = false
opt.signcolumn    = "yes"
opt.showmode      = false   -- lualine shows mode
opt.laststatus    = 3       -- single global statusline

-- Splits
opt.splitright = true
opt.splitbelow = true

-- File handling
opt.swapfile = false
opt.backup   = false
opt.undofile = true
opt.undodir  = vim.fn.expand("~/.local/state/nvim/undo")

-- Performance
opt.updatetime = 250
opt.timeoutlen = 400

-- Clipboard
opt.clipboard = "unnamedplus"

-- Mouse
opt.mouse = "a"

-- Completion
opt.completeopt = "menu,menuone,noselect"

-- Folds via treesitter (disabled by default, open with zR)
opt.foldmethod = "expr"
opt.foldexpr   = "nvim_treesitter#foldexpr()"
opt.foldenable = false
opt.foldlevel  = 99

-- Popup blend (matches terminal opacity)
opt.pumblend = 15
opt.winblend = 15

-- Hide end-of-buffer ~ markers
opt.fillchars = { eob = " " }
