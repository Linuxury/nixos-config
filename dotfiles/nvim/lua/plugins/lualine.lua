-- ============================================================
-- Lualine — status bar
-- Uses matugen colors via the active colorscheme.
-- ============================================================

local function lsp_clients()
  local clients = (vim.lsp.get_clients or vim.lsp.get_active_clients)({ bufnr = 0 })
  if #clients == 0 then return "" end
  local names = {}
  for _, c in ipairs(clients) do
    table.insert(names, c.name)
  end
  return "󰒋 " .. table.concat(names, ", ")
end

require("lualine").setup({
  options = {
    theme                = "auto",   -- picks up current colorscheme
    globalstatus         = true,     -- single bar across all splits
    component_separators = { left = "", right = "" },
    section_separators   = { left = "", right = "" },
    disabled_filetypes   = {
      statusline = { "dashboard", "alpha" },
      winbar     = {},
    },
  },

  sections = {
    lualine_a = {
      { "mode", icon = "" },
    },
    lualine_b = {
      { "branch",   icon = "" },
      { "diff",
        symbols = { added = " ", modified = " ", removed = " " },
        colored = true,
      },
    },
    lualine_c = {
      {
        "filename",
        path      = 1,           -- relative path
        symbols   = { modified = "●", readonly = "", unnamed = "[No Name]" },
      },
    },
    lualine_x = {
      { lsp_clients },
      {
        "diagnostics",
        sources  = { "nvim_diagnostic" },
        symbols  = { error = " ", warn = " ", info = " ", hint = "󰌵 " },
        colored  = true,
      },
      { "encoding" },
      { "fileformat", symbols = { unix = "", dos = "", mac = "" } },
      { "filetype", icon_only = false },
    },
    lualine_y = {
      { "progress" },
    },
    lualine_z = {
      { "location" },
    },
  },

  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { "filename" },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },

  extensions = { "neo-tree", "trouble", "lazy", "toggleterm" },
})
