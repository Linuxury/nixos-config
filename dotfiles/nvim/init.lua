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

-- Colorscheme comes from lua/plugins/base16.lua (RRethy/base16-nvim) +
-- lua/matugen.lua (Noctalia's "neovim" community template output, gitignored
-- — regenerated on every wallpaper change). No explicit setup call needed
-- here; base16.lua's plugin config runs matugen.setup() on load.
