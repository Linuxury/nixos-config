-- ============================================================
-- Telescope — fuzzy finder for files, grep, LSP, git
-- ============================================================

local telescope = require("telescope")
local actions   = require("telescope.actions")

telescope.setup({
  defaults = {
    prompt_prefix   = "   ",
    selection_caret = "  ",
    path_display    = { "smart" },
    file_ignore_patterns = {
      "%.git/",
      "node_modules/",
      "__pycache__/",
      "%.cache/",
      "result/",      -- Nix build results
      "%.direnv/",
    },
    layout_config = {
      horizontal = {
        prompt_position = "top",
        preview_width   = 0.55,
        results_width   = 0.8,
      },
      vertical = {
        mirror = false,
      },
      width        = 0.87,
      height       = 0.80,
      preview_cutoff = 120,
    },
    sorting_strategy = "ascending",
    winblend         = 10,
    border           = true,

    mappings = {
      i = {
        ["<C-k>"]    = actions.move_selection_previous,
        ["<C-j>"]    = actions.move_selection_next,
        ["<C-q>"]    = actions.send_selected_to_qflist + actions.open_qflist,
        ["<M-q>"]    = actions.send_to_qflist + actions.open_qflist,
        ["<C-u>"]    = false,   -- clear prompt (default)
        ["<C-d>"]    = false,   -- clear prompt (default)
        ["<esc>"]    = actions.close,
        ["<C-/>"]    = actions.which_key,
      },
      n = {
        ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
        ["q"]     = actions.close,
      },
    },
  },

  pickers = {
    find_files = {
      hidden       = true,
      follow       = true,    -- follow symlinks
    },
    live_grep = {
      additional_args = { "--hidden" },
    },
    buffers = {
      sort_mru         = true,
      sort_lastused    = true,
      initial_mode     = "normal",
      mappings = {
        n = {
          ["dd"] = actions.delete_buffer,
        },
      },
    },
    git_commits = {
      mappings = {
        i = {
          ["<CR>"] = actions.git_checkout,
        },
      },
    },
  },

  extensions = {
    fzf = {
      fuzzy                   = true,
      override_generic_sorter = true,
      override_file_sorter    = true,
      case_mode               = "smart_case",
    },
  },
})

-- Load the fzf native extension for faster sorting
telescope.load_extension("fzf")
