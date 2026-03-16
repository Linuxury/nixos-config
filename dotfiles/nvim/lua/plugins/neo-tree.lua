-- ============================================================
-- Neo-tree — file explorer sidebar
-- ============================================================

require("neo-tree").setup({
  close_if_last_window = true,   -- close neovim if neo-tree is the last window
  popup_border_style   = "rounded",
  enable_git_status    = true,
  enable_diagnostics   = true,

  default_component_configs = {
    container = {
      enable_character_fade = true,
    },
    indent = {
      indent_size        = 2,
      padding            = 1,
      with_markers       = true,
      indent_marker      = "│",
      last_indent_marker = "└",
      highlight          = "NeoTreeIndentMarker",
      with_expanders     = true,
      expander_collapsed = "",
      expander_expanded  = "",
      expander_highlight = "NeoTreeExpander",
    },
    icon = {
      folder_closed = "",
      folder_open   = "",
      folder_empty  = "",
    },
    modified = {
      symbol    = "●",
      highlight = "NeoTreeModified",
    },
    name = {
      trailing_slash        = false,
      use_git_status_colors = true,
      highlight             = "NeoTreeFileName",
    },
    git_status = {
      symbols = {
        added     = "✚",
        modified  = "",
        deleted   = "✖",
        renamed   = "󰁕",
        untracked = "",
        ignored   = "",
        unstaged  = "󰄱",
        staged    = "",
        conflict  = "",
      },
    },
    file_size = {
      enabled      = true,
      required_width = 64,
    },
    type = {
      enabled        = true,
      required_width = 110,
    },
    last_modified = {
      enabled        = true,
      required_width = 88,
    },
    created = {
      enabled        = true,
      required_width = 110,
    },
    symlink_target = {
      enabled = false,
    },
  },

  window = {
    position = "left",
    width    = 32,
    mapping_options = {
      noremap = true,
      nowait  = true,
    },
    mappings = {
      ["<space>"] = { "toggle_node", nowait = false },
      ["<2-LeftMouse>"] = "open",
      ["<cr>"]  = "open",
      ["<esc>"] = "cancel",
      ["P"]     = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
      ["l"]     = "focus_preview",
      ["S"]     = "open_split",
      ["s"]     = "open_vsplit",
      ["t"]     = "open_tabnew",
      ["w"]     = "open_with_window_picker",
      ["C"]     = "close_node",
      ["z"]     = "close_all_nodes",
      ["Z"]     = "expand_all_nodes",
      ["a"]     = { "add", config = { show_path = "none" } },
      ["A"]     = "add_directory",
      ["d"]     = "delete",
      ["r"]     = "rename",
      ["y"]     = "copy_to_clipboard",
      ["x"]     = "cut_to_clipboard",
      ["p"]     = "paste_from_clipboard",
      ["c"]     = "copy",
      ["m"]     = "move",
      ["q"]     = "close_window",
      ["R"]     = "refresh",
      ["?"]     = "show_help",
      ["<"]     = "prev_source",
      [">"]     = "next_source",
      ["i"]     = "show_file_details",
    },
  },

  filesystem = {
    filtered_items = {
      visible         = false,
      hide_dotfiles   = false,  -- show dotfiles
      hide_gitignored = true,
      hide_by_name    = { ".git", "node_modules", ".cache", "__pycache__" },
    },
    follow_current_file = {
      enabled    = true,
      leave_dirs_open = false,
    },
    group_empty_dirs     = false,
    hijack_netrw_behavior = "open_default",
    use_libuv_file_watcher = true,
  },

  buffers = {
    follow_current_file = {
      enabled          = true,
      leave_dirs_open  = false,
    },
    group_empty_dirs    = true,
    show_unloaded       = true,
  },

  git_status = {
    window = {
      position = "float",
    },
  },
})
