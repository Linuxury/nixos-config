vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.cursorline     = true
vim.opt.scrolloff      = 10
vim.opt.sidescrolloff  = 8
vim.opt.wrap           = false
vim.opt.cmdheight      = 1

vim.opt.tabstop     = 2
vim.opt.shiftwidth  = 2
vim.opt.softtabstop = 2
vim.opt.expandtab   = true
vim.opt.smartindent = true
vim.opt.autoindent  = true

vim.opt.ignorecase = true
vim.opt.smartcase  = true
vim.opt.hlsearch   = false
vim.opt.incsearch  = true

vim.opt.termguicolors  = true
vim.opt.signcolumn     = "yes"
vim.opt.showmatch      = true
vim.opt.completeopt    = "menuone,noinsert,noselect"
vim.opt.showmode       = false
vim.opt.pumheight      = 10
vim.opt.pumblend       = 10
vim.opt.conceallevel   = 0
vim.opt.redrawtime     = 10000
vim.opt.synmaxcol      = 300

vim.opt.backup      = false
vim.opt.writebackup = false
vim.opt.swapfile    = false
vim.opt.undofile    = true
vim.opt.updatetime  = 300
vim.opt.timeoutlen  = 500
vim.opt.autoread    = true

local undodir = vim.fn.expand("~/.local/share/nvim/undodir")
vim.opt.undodir = undodir
vim.fn.mkdir(undodir, "p")

vim.opt.errorbells = false
vim.opt.backspace  = "indent,eol,start"
vim.opt.mouse      = "a"
vim.opt.clipboard:append("unnamedplus")
vim.opt.encoding   = "UTF-8"
vim.opt.wildmenu   = true
vim.opt.wildmode   = "longest:full,full"
vim.opt.showtabline = 2

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

vim.opt.foldmethod = "expr"
vim.opt.foldexpr   = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel  = 99

vim.opt.diffopt:append("vertical")
vim.opt.diffopt:append("algorithm:patience")
vim.opt.diffopt:append("linematch:60")

vim.opt.guicursor = {
  "n-v-c:block",
  "i-ci-ve:ver25",
  "r-cr:hor20",
  "o:hor50",
  "a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor",
  "sm:block-blinkwait175-blinkoff150-blinkon175",
}
