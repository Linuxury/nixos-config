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

-- Terminal transparency: inherit background from any terminal (kitty, alacritty, wezterm, etc.)
local transparent = vim.api.nvim_create_augroup("TransparentBG", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = transparent,
  callback = function()
    local hl = function(name, val)
      val.ctermbg = "NONE"
      vim.api.nvim_set_hl(0, name, val)
    end
    hl("Normal",        { bg = "none" })
    hl("NormalNC",      { bg = "none" })
    hl("NormalFloat",   { bg = "none" })
    hl("FloatBorder",   { bg = "none" })
    hl("SignColumn",    { bg = "none" })
    hl("LineNr",        { bg = "none" })
    hl("CursorLineNr",  { bg = "none" })
    hl("CursorLine",    { bg = "none" })
    hl("StatusLine",    { bg = "none" })
    hl("StatusLineNC",  { bg = "none" })
    hl("VertSplit",     { bg = "none" })
    hl("EndOfBuffer",   { bg = "none" })
    hl("MsgArea",       { bg = "none" })
    hl("TabLine",       { bg = "none" })
    hl("TabLineFill",   { bg = "none" })
    hl("TabLineSel",    { bg = "none" })
    hl("WinSeparator",  { bg = "none" })
    -- Bufferline transparency
    hl("BufferLineFill",        { bg = "none" })
    hl("BufferLineBackground",  { bg = "none" })
    hl("BufferLineBufferVisible", { bg = "none" })
    hl("BufferLineBufferSelected", { bg = "none" })
    hl("BufferLineTab",         { bg = "none" })
    hl("BufferLineTabSelected", { bg = "none" })
    hl("BufferLineTabClose",    { bg = "none" })
    hl("BufferLineSeparator",   { bg = "none" })
    hl("BufferLineOffsetSeparator", { bg = "none" })
  end,
})
-- Fire once on startup, deferred so it runs after all plugin VimEnter hooks
vim.api.nvim_create_autocmd("VimEnter", {
  group = transparent,
  once = true,
  callback = function()
    vim.schedule(function() vim.cmd("doautocmd TransparentBG ColorScheme") end)
  end,
})
