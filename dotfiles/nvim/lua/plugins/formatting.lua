-- ============================================================
-- Formatting (conform.nvim) + Linting (nvim-lint)
-- Formatters/linters are installed via Nix in neovim.nix
-- ============================================================

-- ── conform.nvim — format on save ─────────────────────────
require("conform").setup({
  formatters_by_ft = {
    lua        = { "stylua" },
    nix        = { "alejandra" },
    python     = { "ruff_format", "ruff_fix" },
    javascript = { "prettier" },
    typescript = { "prettier" },
    json       = { "prettier" },
    jsonc      = { "prettier" },
    yaml       = { "prettier" },
    markdown   = { "prettier" },
    html       = { "prettier" },
    css        = { "prettier" },
    sh         = { "shfmt" },
    bash       = { "shfmt" },
    zsh        = { "shfmt" },
    toml       = { "taplo" },
    rust       = { "rustfmt" },
    go         = { "gofmt" },
    c          = { "clang_format" },
    cpp        = { "clang_format" },
    -- fallback: use LSP formatter for anything not listed
    ["_"]      = { "trim_whitespace" },
  },

  -- Format on save (async so it doesn't block)
  format_on_save = function(bufnr)
    -- Disable for certain filetypes or large files
    local disable_filetypes = { "sql", "java" }
    if vim.tbl_contains(disable_filetypes, vim.bo[bufnr].filetype) then
      return
    end
    if vim.api.nvim_buf_line_count(bufnr) > 10000 then
      return
    end
    return { timeout_ms = 3000, lsp_fallback = true }
  end,

  -- Notify on format errors
  notify_on_error = true,

  -- Log level for debugging (change to "debug" if formatters aren't working)
  log_level = vim.log.levels.ERROR,
})

-- ── nvim-lint — async linting ─────────────────────────────
local lint = require("lint")

lint.linters_by_ft = {
  python     = { "ruff" },
  javascript = { "eslint_d" },
  typescript = { "eslint_d" },
  sh         = { "shellcheck" },
  bash       = { "shellcheck" },
  nix        = { "statix" },
  markdown   = { "markdownlint" },
  yaml       = { "yamllint" },
}

-- Run linting on relevant events
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
  callback = function()
    -- Only lint if a linter is configured for this filetype
    local ft = vim.bo.filetype
    if lint.linters_by_ft[ft] then
      lint.try_lint()
    end
  end,
})
