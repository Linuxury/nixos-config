-- ============================================================
-- Autocommands
-- ============================================================

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ─── Auto-layout on first file open ──────────────────────
-- Opens: NeoTree (left) | Editor (center) | Claude (right)
--                    Terminal (bottom)
-- Fires once per session on the first real file read.
augroup("AutoLayout", { clear = true })
autocmd("BufReadPost", {
  group = "AutoLayout",
  once  = true,
  callback = function()
    vim.schedule(function()
      local buf  = vim.api.nvim_get_current_buf()
      local name = vim.api.nvim_buf_get_name(buf)
      if name == "" then return end

      -- Remember the editor window so we can return to it after opening panels
      local editor_win = vim.api.nvim_get_current_win()

      -- Left: file explorer (neo-tree stays pinned, doesn't take a bufferline slot)
      vim.cmd("Neotree show")

      -- Right: Claude Code panel (split_side = "right" in terminal.lua keeps it pinned)
      -- Return focus to the editor window explicitly rather than relying on wincmd direction
      vim.cmd("ClaudeCode")
      vim.api.nvim_set_current_win(editor_win)
    end)
  end,
})

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

-- ─── Transparent background (survives colorscheme changes) ─
augroup("TransparentBg", { clear = true })
autocmd("ColorScheme", {
  group = "TransparentBg",
  pattern = "*",
  callback = function()
    vim.api.nvim_set_hl(0, "Normal",    { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NormalNC",  { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "SignColumn",{ bg = "NONE" })
    vim.api.nvim_set_hl(0, "FoldColumn",{ bg = "NONE" })
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

-- ─── Neo-tree: auto-open file preview as side split ───────
-- When neo-tree opens, automatically trigger the preview pane (same as pressing P)
-- so you can see file contents while navigating without any extra keypress.
-- Checks if a preview window is already visible before firing to avoid toggling it closed.
augroup("NeoTreeAutoPreview", { clear = true })
autocmd("FileType", {
  group   = "NeoTreeAutoPreview",
  pattern = "neo-tree",
  callback = function(ev)
    vim.defer_fn(function()
      local preview_open = false
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "neo-tree-preview" then
          preview_open = true
          break
        end
      end
      if not preview_open then
        local tree_win = vim.fn.bufwinid(ev.buf)
        if tree_win ~= -1 and vim.api.nvim_win_is_valid(tree_win) then
          vim.fn.win_execute(tree_win, "normal! P")
        end
      end
    end, 200)
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
