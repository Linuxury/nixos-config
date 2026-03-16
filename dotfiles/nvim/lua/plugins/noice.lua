-- ============================================================
-- Noice — fancy UI for cmdline, messages, and popups
-- ============================================================

require("noice").setup({
  lsp = {
    override = {
      -- Use noice's enhanced renderers for LSP markdown
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"]                = true,
      ["cmp.entry.get_documentation"]                  = true,
    },
    hover = {
      enabled = true,
    },
    signature = {
      enabled = true,
      auto_open = {
        enabled    = true,
        trigger    = true,
        luasnip    = true,
        throttle   = 50,
      },
    },
    progress = {
      enabled = true,
    },
    message = {
      enabled = true,
    },
    documentation = {
      enabled = true,
      view    = "hover",
    },
  },
  presets = {
    bottom_search         = true,   -- classic search bar at the bottom
    command_palette       = true,   -- cmdline + popupmenu together
    long_message_to_split = true,   -- long messages go to a split
    inc_rename            = false,  -- disable if not using inc-rename
    lsp_doc_border        = true,   -- border on hover/signature windows
  },
  routes = {
    -- Suppress common noisy messages
    { filter = { event = "msg_show", any = {
        { find = "%d+L, %d+B" },
        { find = "; after #%d+" },
        { find = "; before #%d+" },
        { find = "%d fewer lines" },
        { find = "%d more lines" },
      }},
      opts = { skip = true },
    },
    -- Send long messages to a split instead of the cmdline
    { filter = { event = "msg_show", min_height = 10 },
      view = "split",
    },
  },
})

-- ── nvim-notify ────────────────────────────────────────────
require("notify").setup({
  background_colour = "#000000",
  render            = "minimal",
  timeout           = 3000,
  max_width         = 50,
  stages            = "fade_in_slide_out",
  fps               = 30,
})

vim.notify = require("notify")
