return function(capabilities)
  vim.lsp.config("html", {
    capabilities = capabilities,
    filetypes    = { "html" },
  })
end
