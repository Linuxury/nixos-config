-- ============================================================
-- Which-key v3 — shows available keybindings in a popup
-- Press <leader> and wait ~300ms to see all options
-- ============================================================

local wk = require("which-key")

wk.setup({
  preset  = "modern",  -- "classic", "modern", or "helix"
  delay   = 300,
  notify  = false,     -- suppress startup notification

  plugins = {
    marks      = true,
    registers  = true,
    spelling   = { enabled = true, suggestions = 20 },
    presets    = {
      operators    = true,
      motions      = true,
      text_objects = true,
      windows      = true,
      nav          = true,
      z            = true,
      g            = true,
    },
  },

  win = {
    border   = "rounded",
    padding  = { 1, 2 },
    wo       = { winblend = 10 },
  },

  layout = {
    width  = { min = 20 },
    spacing = 3,
  },

  icons = {
    breadcrumb = "»",
    separator  = "➜",
    group      = "+",
  },

  show_help = true,
  show_keys = true,
})

-- Register group names (shown as headers in the popup)
wk.add({
  { "<leader>b",  group = "Buffers"               },
  { "<leader>c",  group = "Claude Code"            },
  { "<leader>e",  group = "Explorer"               },
  { "<leader>f",  group = "Find / Format"          },
  { "<leader>g",  group = "Git"                    },
  { "<leader>h",  group = "Harpoon"                },
  { "<leader>o",  group = "Opencode"               },
  { "<leader>s",  group = "Splits"                 },
  { "<leader>t",  group = "Toggle"                 },
  { "<leader>w",  group = "Save"                   },
  { "<leader>x",  group = "Diagnostics / Trouble"  },
})
