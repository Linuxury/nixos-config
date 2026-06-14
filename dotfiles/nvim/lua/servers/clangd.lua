return function(capabilities)
  vim.lsp.config("clangd", {
    capabilities = capabilities,
    filetypes    = { "c", "cpp", "objc", "objcpp" },
  })
end
