-- Prepend the matugen-generated colors dir so require("matugen-colors") works.
-- This file is written by the matugen systemd service on every wallpaper change.
vim.opt.runtimepath:prepend(vim.fn.expand("~/.local/share/nvim"))
vim.fn.mkdir(vim.fn.expand("~/.local/share/nvim/lua"), "p")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("options")
require("keymaps")

require("lazy").setup("plugins", {
  change_detection = { notify = false },
  checker = { enabled = false },
  rocks = { hererocks = false },
})

-- Apply matugen colorscheme (pure Lua, no plugin dep — safe to call immediately)
require("theme").setup()
