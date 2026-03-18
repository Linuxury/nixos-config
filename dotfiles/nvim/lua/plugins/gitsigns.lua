require("gitsigns").setup({
  signs = {
    add          = { text = "▎" },
    change       = { text = "▎" },
    delete       = { text = "" },
    topdelete    = { text = "" },
    changedelete = { text = "▎" },
    untracked    = { text = "▎" },
  },
  signs_staged_enable = true,
  current_line_blame  = false,
  preview_config = {
    border   = "rounded",
    style    = "minimal",
    relative = "cursor",
    row      = 0,
    col      = 1,
  },

  on_attach = function(bufnr)
    local gs  = package.loaded.gitsigns
    local map = function(mode, l, r, desc)
      vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc, noremap = true, silent = true })
    end

    map("n", "]h", function()
      if vim.wo.diff then return "]c" end
      vim.schedule(function() gs.next_hunk() end)
      return "<Ignore>"
    end, "Next hunk")

    map("n", "[h", function()
      if vim.wo.diff then return "[c" end
      vim.schedule(function() gs.prev_hunk() end)
      return "<Ignore>"
    end, "Prev hunk")

    map("n", "<leader>gs", gs.stage_hunk,   "Stage hunk")
    map("n", "<leader>gr", gs.reset_hunk,   "Reset hunk")
    map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
    map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
    map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle line blame")
    map("n", "<leader>gx", gs.diffthis, "Diff this")

    map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<cr>", "Select hunk")
  end,
})
