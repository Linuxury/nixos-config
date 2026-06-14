return function(capabilities)
  vim.lsp.config("hyprls", {
    cmd          = { "hyprls" },
    capabilities = capabilities,
    filetypes    = { "hyprlang" },
  })
end
