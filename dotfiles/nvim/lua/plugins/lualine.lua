-- Custom theme: colored mode pill, everything else transparent (inherits terminal)
local theme = {
  normal  = { a = { fg = 0, bg = 2, gui = "bold" }, b = { fg = 7, bg = "none" }, c = { fg = 7, bg = "none" },
              y = { fg = 0, bg = 5, gui = "bold" }, z = { fg = 0, bg = 3, gui = "bold" } },
  insert  = { a = { fg = 0, bg = 4, gui = "bold" }, y = { fg = 0, bg = 5, gui = "bold" }, z = { fg = 0, bg = 3, gui = "bold" } },
  visual  = { a = { fg = 0, bg = 5, gui = "bold" }, y = { fg = 0, bg = 5, gui = "bold" }, z = { fg = 0, bg = 3, gui = "bold" } },
  replace = { a = { fg = 0, bg = 1, gui = "bold" }, y = { fg = 0, bg = 5, gui = "bold" }, z = { fg = 0, bg = 3, gui = "bold" } },
  command = { a = { fg = 0, bg = 3, gui = "bold" }, y = { fg = 0, bg = 5, gui = "bold" }, z = { fg = 0, bg = 3, gui = "bold" } },
  inactive = { a = { fg = 8, bg = "none" }, b = { fg = 8, bg = "none" }, c = { fg = 8, bg = "none" } },
}

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
    theme                = theme,
    globalstatus         = true,
    component_separators = { left = "○", right = "○" },
    section_separators   = { left = "", right = "/" },
  },

  sections = {
    lualine_a = {
      { "mode", fmt = function(s) return "✕ " .. s end },
    },
    lualine_b = {
      { "branch", icon = "" },
      { "diff", symbols = { added = " ", modified = " ", removed = " " } },
    },
    lualine_c = {
      { "filename", path = 1, symbols = { modified = "●", readonly = "", unnamed = "[No Name]" } },
    },
    lualine_x = {
      { lsp_clients },
      { "diagnostics", sources = { "nvim_diagnostic" }, symbols = { error = " ", warn = " ", info = " ", hint = "󰌵 " } },
    },
    lualine_y = {
      { function() return " " .. (vim.env.USER or "user") end },
    },
    lualine_z = {
      { "location", fmt = function(s) return "≡ " .. s end },
    },
  },

  inactive_sections = {
    lualine_c = { "filename" },
    lualine_x = { { "location", fmt = function(s) return "≡ " .. s end } },
  },
})
