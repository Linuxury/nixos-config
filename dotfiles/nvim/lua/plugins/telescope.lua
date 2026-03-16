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
      -- Version control
      "%.git/",
      -- Package managers / build artifacts
      "node_modules/",
      "__pycache__/",
      "%.direnv/",
      "result/",        -- Nix build results
      "%.cargo/registry/",
      "%.rustup/",
      -- Caches and logs
      "%.cache/",
      "%.npm/_logs/",
      "%.npm/cache/",
      "%.local/share/Steam/",
      "%.local/share/flatpak/",
      "%.local/lib/",
      "%.steam/",
      "%.var/",
      -- Binary / large files
      "%.exe$",
      "%.so$",
      "%.dylib$",
      "%.class$",
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
      hidden       = false,   -- don't search hidden dirs by default
      follow       = false,   -- don't follow symlinks (avoids crawling ~/Pictures/Wallpapers etc.)
      -- Use fd if available: faster and respects .gitignore automatically
      find_command = (function()
        if vim.fn.executable("fd") == 1 then
          return { "fd", "--type", "f", "--color", "never", "--strip-cwd-prefix" }
        end
      end)(),
    },
    live_grep = {
      additional_args = {},   -- no --hidden: skip dotfiles in grep too
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
