-- ============================================================
-- Diffview — side-by-side diffs and file history
-- Open with <leader>gd (diff) or <leader>gh (file history)
-- ============================================================

local actions = require("diffview.actions")

require("diffview").setup({
  diff_binaries    = false,
  enhanced_diff_hl = true,
  git_cmd          = { "git" },
  use_icons        = true,
  show_help_hints  = true,
  watch_index      = true,

  icons = {
    folder_closed = "",
    folder_open   = "",
  },

  signs = {
    fold_closed = "",
    fold_open   = "",
    done        = "✓",
  },

  view = {
    default = {
      layout     = "diff2_horizontal",
      winbar_info = false,
    },
    merge_tool = {
      layout          = "diff3_horizontal",
      disable_diagnostics = true,
      winbar_info     = true,
    },
    file_history = {
      layout     = "diff2_horizontal",
      winbar_info = false,
    },
  },

  file_panel = {
    listing_style     = "tree",
    tree_options      = {
      flatten_dirs      = true,
      folder_statuses   = "only_folded",
    },
    win_config        = {
      position = "left",
      width    = 35,
      win_opts = {},
    },
  },

  file_history_panel = {
    log_options = {
      git = {
        single_file = {
          diff_merges = "combined",
        },
        multi_file  = {
          diff_merges = "first-parent",
        },
      },
    },
    win_config = {
      position = "bottom",
      height   = 16,
      win_opts = {},
    },
  },

  commit_log_panel = {
    win_config = { win_opts = {} },
  },

  default_args = {
    DiffviewOpen        = {},
    DiffviewFileHistory = {},
  },

  hooks = {},

  keymaps = {
    disable_defaults = false,
    view = {
      { "n", "<leader>e",  actions.toggle_files, { desc = "Toggle the file panel." } },
      { "n", "g<C-x>",     actions.cycle_layout, { desc = "Cycle through available layouts." } },
      { "n", "[x",         actions.prev_conflict, { desc = "Jump to prev conflict" } },
      { "n", "]x",         actions.next_conflict, { desc = "Jump to next conflict" } },
    },
    file_panel = {
      { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
    },
    file_history_panel = {
      { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
    },
  },
})
