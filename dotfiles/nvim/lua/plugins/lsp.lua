-- Servers installed via Nix (lua-language-server, nil)

vim.diagnostic.config({
  virtual_text    = true,
  signs           = true,
  underline       = true,
  update_in_insert = false,
  severity_sort   = true,
  float = {
    border = "rounded",
    source = true,
    header = "",
    prefix = "",
  },
})

local signs = { Error = " ", Warn = " ", Hint = "󰌵 ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

local function on_attach(_, bufnr)
  local map = function(keys, func, desc)
    vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc, noremap = true, silent = true })
  end

  map("gd",         vim.lsp.buf.definition,      "Go to definition")
  map("gD",         vim.lsp.buf.declaration,     "Go to declaration")
  map("gi",         vim.lsp.buf.implementation,  "Go to implementation")
  map("gt",         vim.lsp.buf.type_definition, "Go to type definition")
  map("gr",         "<cmd>Telescope lsp_references<cr>", "References")
  map("K",          vim.lsp.buf.hover,            "Hover docs")
  map("<C-k>",      vim.lsp.buf.signature_help,   "Signature help")
  map("<leader>rn", vim.lsp.buf.rename,           "Rename symbol")
  map("<leader>ca", vim.lsp.buf.code_action,      "Code actions")
  map("<leader>f",  function() vim.lsp.buf.format({ async = true }) end, "Format file")
  map("[d",         vim.diagnostic.goto_prev,     "Prev diagnostic")
  map("]d",         vim.diagnostic.goto_next,     "Next diagnostic")
  map("<leader>dl", vim.diagnostic.open_float,    "Diagnostic details")
end

local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
  vim.lsp.handlers.hover, { border = "rounded" }
)
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
  vim.lsp.handlers.signature_help, { border = "rounded" }
)

vim.lsp.config("*", {
  on_attach    = on_attach,
  capabilities = capabilities,
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime     = { version = "LuaJIT" },
      workspace   = { checkThirdParty = false, library = vim.api.nvim_get_runtime_file("", true) },
      telemetry   = { enable = false },
      diagnostics = { globals = { "vim" } },
      completion  = { callSnippet = "Replace" },
    },
  },
})

vim.lsp.config("nil_ls", {
  settings = {
    ["nil"] = {
      formatting = { command = { "alejandra" } },
      nix = { flake = { autoArchive = true } },
    },
  },
})

vim.lsp.enable({ "lua_ls", "nil_ls" })
