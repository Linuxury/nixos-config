return function(capabilities)
  vim.lsp.config("pyright", {
    capabilities = capabilities,
    filetypes    = { "python" },
  })
end
