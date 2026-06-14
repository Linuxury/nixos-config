local M = {}

M.setup = function()
  vim.diagnostic.config({
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = " ",
        [vim.diagnostic.severity.WARN]  = " ",
        [vim.diagnostic.severity.INFO]  = " ",
        [vim.diagnostic.severity.HINT]  = "",
      },
    },
    virtual_text = {
      prefix  = "●",
      spacing = 2,
      severity = { min = vim.diagnostic.severity.HINT },
    },
    underline    = true,
    float        = { source = "always" },
    severity_sort = true,
    update_in_insert = false,
  })
end

return M
