local telescope = require("telescope")
local actions   = require("telescope.actions")

telescope.setup({
  defaults = {
    prompt_prefix   = "   ",
    selection_caret = "  ",
    path_display    = { "smart" },
    file_ignore_patterns = {
      "%.git/", "node_modules/", "__pycache__/", "%.direnv/",
      "result/", "%.cache/", "%.local/share/Steam/",
      "%.local/share/flatpak/", "%.var/",
    },
    layout_config = {
      horizontal = { prompt_position = "top", preview_width = 0.55 },
      width = 0.87, height = 0.80, preview_cutoff = 120,
    },
    sorting_strategy = "ascending",
    winblend         = 10,
    mappings = {
      i = {
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
        ["<esc>"] = actions.close,
      },
      n = {
        ["q"] = actions.close,
      },
    },
  },

  pickers = {
    find_files = {
      find_command = (function()
        if vim.fn.executable("fd") == 1 then
          return { "fd", "--type", "f", "--color", "never", "--strip-cwd-prefix" }
        end
      end)(),
    },
    buffers = {
      sort_mru      = true,
      sort_lastused = true,
      initial_mode  = "normal",
      mappings = { n = { ["dd"] = actions.delete_buffer } },
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

telescope.load_extension("fzf")
