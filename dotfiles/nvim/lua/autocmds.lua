-- ============================================================
-- Autocommands
-- ============================================================

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ─── Highlight on yank ────────────────────────────────────
augroup("YankHighlight", { clear = true })
autocmd("TextYankPost", {
  group = "YankHighlight",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-- ─── Trim trailing whitespace on save ─────────────────────
augroup("TrimWhitespace", { clear = true })
autocmd("BufWritePre", {
  group = "TrimWhitespace",
  pattern = "*",
  callback = function()
    local save = vim.fn.winsaveview()
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.winrestview(save)
  end,
})

-- ─── Remember cursor position ─────────────────────────────
augroup("RestoreCursor", { clear = true })
autocmd("BufReadPost", {
  group = "RestoreCursor",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- ─── Close certain windows with q ────────────────────────
augroup("QuickClose", { clear = true })
autocmd("FileType", {
  group = "QuickClose",
  pattern = { "help", "man", "qf", "trouble", "lspinfo", "checkhealth" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- ─── Reload matugen colorscheme when the file changes ─────
-- Matugen regenerates ~/.config/nvim/colors/matugen.lua on wallpaper change.
-- This autocmd detects the file modification and reloads the colorscheme live.
augroup("MatugenReload", { clear = true })
autocmd({ "FocusGained", "BufEnter" }, {
  group = "MatugenReload",
  callback = function()
    local colors_file = vim.fn.expand("~/.config/nvim/colors/matugen.lua")
    if vim.fn.filereadable(colors_file) == 1 then
      local mtime = vim.fn.getftime(colors_file)
      if not vim.g._matugen_mtime or vim.g._matugen_mtime ~= mtime then
        vim.g._matugen_mtime = mtime
        if vim.g.colors_name == "matugen" then
          vim.cmd("colorscheme matugen")
        end
      end
    end
  end,
})

-- ─── Filetype-specific settings ───────────────────────────
augroup("FileTypeSettings", { clear = true })

-- Markdown / text: wrap + spell
autocmd("FileType", {
  group = "FileTypeSettings",
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap      = true
    vim.opt_local.spell     = true
    vim.opt_local.linebreak = true
  end,
})

-- Go: tabs not spaces
autocmd("FileType", {
  group = "FileTypeSettings",
  pattern = "go",
  callback = function()
    vim.opt_local.expandtab  = false
    vim.opt_local.tabstop    = 4
    vim.opt_local.shiftwidth = 4
  end,
})

-- Nix: 2 spaces (already default, but explicit)
autocmd("FileType", {
  group = "FileTypeSettings",
  pattern = "nix",
  callback = function()
    vim.opt_local.tabstop    = 2
    vim.opt_local.shiftwidth = 2
  end,
})

-- ─── Auto-resize splits on window resize ──────────────────
augroup("ResizeSplits", { clear = true })
autocmd("VimResized", {
  group = "ResizeSplits",
  callback = function()
    vim.cmd("wincmd =")
  end,
})

-- ─── Disable diagnostics in insert mode ───────────────────
augroup("DiagnosticInsert", { clear = true })
autocmd("InsertEnter", {
  group = "DiagnosticInsert",
  callback = function()
    vim.diagnostic.config({ virtual_text = false })
  end,
})
autocmd("InsertLeave", {
  group = "DiagnosticInsert",
  callback = function()
    vim.diagnostic.config({ virtual_text = true })
  end,
})
