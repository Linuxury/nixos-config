return {
  -- Statusline + buffer tabs
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    config = function()
      local wide = function() return vim.fn.winwidth(0) > 100 end

      require("lualine").setup({
        options = {
          icons_enabled    = true,
          theme            = "auto",
          section_separators   = { left = "", right = "" },
          component_separators = { left = "", right = "" },
          disabled_filetypes   = { "snacks_dashboard" },
        },
        sections = {
          lualine_a = { { "mode", fmt = function(s)
            return wide() and (" " .. s) or (" " .. s:sub(1, 1))
          end } },
          lualine_b = { "branch" },
          lualine_c = { { "filename", file_status = true, path = 0 } },
          lualine_x = {
            { require("lazy.status").updates, cond = require("lazy.status").has_updates },
            { "diagnostics", sources = { "nvim_diagnostic" }, sections = { "error", "warn" },
              symbols = { error = " ", warn = " " }, colored = false, cond = wide },
            { "diff", colored = false,
              symbols = { added = " ", modified = " ", removed = " " }, cond = wide },
            { "filetype",  cond = wide },
            { "encoding",  cond = wide },
          },
          lualine_y = { "location" },
          lualine_z = { "progress" },
        },
        inactive_sections = {
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { { "location", padding = 0 } },
        },
        tabline = {
          lualine_a = { { "buffers", show_filename_only = true } },
        },
      })
    end,
  },

  -- Keybinding hints popup
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      delay  = 200,
      spec = {
        { "<leader>b", group = "Buffer" },
        { "<leader>f", group = "Files" },
        { "<leader>g", group = "Git" },
        { "<leader>s", group = "Search" },
        { "<leader>S", group = "Settings" },
        { "<leader>m", group = "Markdown" },
        { "<leader>a", group = "AI" },
        { "<leader>r", group = "Config" },
      },
    },
    keys = {
      { "<leader>?", function() require("which-key").show({ global = false }) end,
        desc = "Buffer Keymaps" },
    },
  },
}
