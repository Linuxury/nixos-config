-- ================================================================================================
-- TITLE : colorscheme (overlay)
-- ABOUT : Dynamic theme that matches your desktop session — matugen for Hyprland
-- ================================================================================================

return {
  { "catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000 },
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
  { "Mofiqul/vscode.nvim", name = "vscode", lazy = false, priority = 1000 },
  { "sainnhe/everforest", lazy = false, priority = 1000 },
  { "sainnhe/gruvbox-material", lazy = false, priority = 1000 },
  { "sainnhe/sonokai", lazy = false, priority = 1000 },
  { "shaunsingh/nord.nvim", lazy = false, priority = 1000 },
  { "tjdevries/colorbuddy.nvim", lazy = false, priority = 1000 },
  { "olimorris/onedark.nvim", lazy = false, priority = 1000 },
  { "tanvirtin/monokai.nvim", lazy = false, priority = 1000 },
  { "nyoom-engineering/oxocarbon.nvim", lazy = false, priority = 1000 },
  { "rebelot/kanagawa.nvim", lazy = false, priority = 1000 },
  { "Mofiqul/dracula.nvim", name = "dracula", lazy = false, priority = 1000 },
  { "rose-pine/neovim", name = "rose-pine", lazy = false, priority = 1000 },
  { "kdheepak/monochrome.nvim", lazy = false, priority = 1000 },

  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          -- Load matugen plugin first (for Hyprland)
          local matugen_ok, _ = pcall(require, "plugins.matugen")
          if matugen_ok then
            -- matugen.lua is loaded, theme loader will use it
          end
          -- Then load the theme
          require('utils.theme').load_theme()
        end,
      })
    end,
  },
}
