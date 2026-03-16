-- ============================================================
-- LSP — Language Server Protocol
-- neovim 0.11 + lspconfig 2.7.x: vim.lsp.config / vim.lsp.enable API
-- Servers are installed via Nix packages in modules/home/neovim.nix
-- ============================================================

-- ── Diagnostics appearance ────────────────────────────────
vim.diagnostic.config({
  virtual_text    = true,
  signs           = true,
  underline       = true,
  update_in_insert = false,
  severity_sort   = true,
  float = {
    border  = "rounded",
    source  = true,
    header  = "",
    prefix  = "",
  },
})

local signs = {
  Error = " ",
  Warn  = " ",
  Hint  = "󰌵 ",
  Info  = " ",
}
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

-- ── on_attach — runs for every buffer that attaches an LSP ──
local function on_attach(_, bufnr)
  local map = function(keys, func, desc)
    vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc, noremap = true, silent = true })
  end

  map("gd",  vim.lsp.buf.definition,       "Go to definition")
  map("gD",  vim.lsp.buf.declaration,      "Go to declaration")
  map("gi",  vim.lsp.buf.implementation,   "Go to implementation")
  map("gt",  vim.lsp.buf.type_definition,  "Go to type definition")
  map("gr",  "<cmd>Telescope lsp_references<cr>", "References")
  map("K",    vim.lsp.buf.hover,           "Hover docs")
  map("<C-k>", vim.lsp.buf.signature_help, "Signature help")
  map("<leader>rn", vim.lsp.buf.rename,      "Rename symbol")
  map("<leader>ca", vim.lsp.buf.code_action, "Code actions")
  map("<leader>f",  function()
    require("conform").format({ async = true, lsp_fallback = true })
  end, "Format file")
  map("[d", vim.diagnostic.goto_prev, "Prev diagnostic")
  map("]d", vim.diagnostic.goto_next, "Next diagnostic")
  map("<leader>dl", vim.diagnostic.open_float, "Diagnostic details")
  map("<leader>wa", vim.lsp.buf.add_workspace_folder,    "Add workspace folder")
  map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
  map("<leader>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, "List workspace folders")
end

-- ── Capabilities — enhanced with cmp-nvim-lsp ─────────────
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- LSP hover window border
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
  vim.lsp.handlers.hover,
  { border = "rounded" }
)
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
  vim.lsp.handlers.signature_help,
  { border = "rounded" }
)

-- ── Global defaults — applied to all servers ──────────────
-- lspconfig's lsp/ files are auto-loaded from runtimepath;
-- this extends every server with our on_attach + capabilities.
vim.lsp.config("*", {
  on_attach    = on_attach,
  capabilities = capabilities,
})

-- ── Server-specific overrides ─────────────────────────────
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

vim.lsp.config("ts_ls", {
  settings = {
    typescript = { inlayHints = { includeInlayParameterNameHints = "all" } },
    javascript = { inlayHints = { includeInlayParameterNameHints = "all" } },
  },
})

vim.lsp.config("pyright", {
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",
        autoSearchPaths  = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
})

vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = {
      checkOnSave = { command = "clippy" },
      inlayHints  = { enable = true },
    },
  },
})

vim.lsp.config("yamlls", {
  settings = {
    yaml = {
      schemaStore = { enable = true },
      validate    = true,
    },
  },
})

vim.lsp.config("clangd", {
  cmd = { "clangd", "--background-index", "--suggest-missing-includes" },
})

-- ── Enable all servers ────────────────────────────────────
vim.lsp.enable({
  "lua_ls",
  "nil_ls",
  "bashls",
  "ts_ls",
  "pyright",
  "rust_analyzer",
  "marksman",
  "yamlls",
  "taplo",
  "clangd",
})

-- ── Fidget — LSP loading spinner ──────────────────────────
require("fidget").setup({
  notification = {
    window = { winblend = 100 },
  },
})

-- ── Trouble — diagnostics panel ───────────────────────────
require("trouble").setup({
  modes = {
    diagnostics = {
      auto_open  = false,
      auto_close = true,
    },
  },
})

-- ── Todo Comments ─────────────────────────────────────────
require("todo-comments").setup({
  signs      = true,
  sign_priority = 8,
  keywords   = {
    FIX  = { icon = " ", color = "error",   alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
    TODO = { icon = " ", color = "info"  },
    HACK = { icon = " ", color = "warning" },
    WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
    PERF = { icon = "󰅙 ", color = "default", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
    NOTE = { icon = "󰍨 ", color = "hint",  alt = { "INFO" } },
    TEST = { icon = "⏲ ", color = "test",  alt = { "TESTING", "PASSED", "FAILED" } },
  },
  gui_style  = { fg = "NONE", bg = "BOLD" },
  merge_keywords = true,
  highlight  = {
    multiline     = true,
    before        = "",
    keyword       = "wide",
    after         = "fg",
    pattern       = [[.*<(KEYWORDS)\s*:]],
    comments_only = true,
    max_line_len  = 400,
    exclude       = {},
  },
  colors = {
    error   = { "DiagnosticError", "ErrorMsg", "#DC2626" },
    warning = { "DiagnosticWarn",  "WarningMsg", "#FBBF24" },
    info    = { "DiagnosticInfo",  "#2563EB" },
    hint    = { "DiagnosticHint",  "#10B981" },
    default = { "Identifier",      "#7C3AED" },
    test    = { "Identifier",      "#FF006E" },
  },
})
