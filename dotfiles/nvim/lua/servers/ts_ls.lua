return function(capabilities)
  vim.lsp.config("ts_ls", {
    capabilities = capabilities,
    filetypes    = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  })
end
