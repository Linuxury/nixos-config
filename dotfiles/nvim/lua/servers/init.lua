-- LSP capabilities from blink.cmp
local capabilities = require("blink.cmp").get_lsp_capabilities(
  vim.lsp.protocol.make_client_capabilities()
)

require("servers.nil_ls")(capabilities)
require("servers.lua_ls")(capabilities)
require("servers.bashls")(capabilities)
require("servers.html")(capabilities)
require("servers.cssls")(capabilities)
require("servers.ts_ls")(capabilities)
require("servers.tailwindcss")(capabilities)
require("servers.pyright")(capabilities)
require("servers.clangd")(capabilities)
require("servers.hyprls")(capabilities)

vim.lsp.enable({
  "nil_ls", "lua_ls", "bashls", "html", "cssls",
  "ts_ls", "tailwindcss", "pyright", "clangd", "hyprls",
})
