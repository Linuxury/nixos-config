return function(capabilities)
  vim.lsp.config("nil_ls", {
    cmd          = { "nil" },
    capabilities = capabilities,
    filetypes    = { "nix" },
  })
end
