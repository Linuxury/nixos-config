return function(capabilities)
  vim.lsp.config("cssls", {
    capabilities = capabilities,
    filetypes    = { "css", "scss", "less" },
  })
end
