-- ============================================================
-- Gitsigns — git status in the gutter + inline blame
-- ============================================================

require("gitsigns").setup({
  signs = {
    add          = { text = "▎" },
    change       = { text = "▎" },
    delete       = { text = "" },
    topdelete    = { text = "" },
    changedelete = { text = "▎" },
    untracked    = { text = "▎" },
  },
  signs_staged = {
    add          = { text = "▎" },
    change       = { text = "▎" },
    delete       = { text = "" },
    topdelete    = { text = "" },
    changedelete = { text = "▎" },
  },
  signs_staged_enable   = true,
  signcolumn            = true,
  numhl                 = false,
  linehl                = false,
  word_diff             = false,
  watch_gitdir          = { follow_files = true },
  auto_attach           = true,
  attach_to_untracked   = false,
  current_line_blame    = false,   -- toggle with <leader>gb below
  current_line_blame_opts = {
    virt_text         = true,
    virt_text_pos     = "eol",
    delay             = 1000,
    ignore_whitespace = false,
  },
  current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> — <summary>",
  sign_priority                = 6,
  update_debounce              = 100,
  status_formatter             = nil,
  max_file_length              = 40000,
  preview_config               = {
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

    -- Navigation
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

    -- Actions
    map("n", "<leader>gs",  gs.stage_hunk,            "Stage hunk")
    map("n", "<leader>gr",  gs.reset_hunk,            "Reset hunk")
    map("v", "<leader>gs",  function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage hunk (selection)")
    map("v", "<leader>gr",  function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset hunk (selection)")
    map("n", "<leader>gS",  gs.stage_buffer,          "Stage buffer")
    map("n", "<leader>gu",  gs.undo_stage_hunk,       "Undo stage hunk")
    map("n", "<leader>gR",  gs.reset_buffer,          "Reset buffer")
    map("n", "<leader>gp",  gs.preview_hunk,          "Preview hunk")
    map("n", "<leader>gb",  function() gs.blame_line({ full = true }) end, "Blame line")
    map("n", "<leader>gB",  gs.toggle_current_line_blame, "Toggle line blame")
    map("n", "<leader>gx",  gs.diffthis,              "Diff this")
    map("n", "<leader>gX",  function() gs.diffthis("~") end, "Diff this ~")
    map("n", "<leader>gD",  gs.toggle_deleted,        "Toggle deleted")

    -- Text objects — select hunks with ih/ah
    map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<cr>", "Select hunk")
    map({ "o", "x" }, "ah", ":<C-U>Gitsigns select_hunk<cr>", "Select hunk")
  end,
})
