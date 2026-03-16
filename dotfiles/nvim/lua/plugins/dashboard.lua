-- ============================================================
-- Dashboard — startup screen with Naruto chibi image
--
-- TWO OPTIONS — toggle by commenting/uncommenting:
--
--   OPTION A (default): Renders the actual PNG via image.nvim
--                       Requires kitty graphics protocol (works in ghostty)
--
--   OPTION B:           ASCII art text header (always works everywhere)
--                       Uncomment the `header` block below and
--                       comment out the image autocmd block.
-- ============================================================

local db = require("dashboard")

-- ── OPTION B: ASCII art header (comment out to use image instead) ──────────
-- local ascii_header = {
--   "",
--   "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
--   "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
--   "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
--   "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
--   "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
--   "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
--   "",
-- }

-- Shared shortcuts for the center menu
local center = {
  {
    icon = "  ",
    desc = "Find file",
    key  = "f",
    action = "Telescope find_files",
  },
  {
    icon = "  ",
    desc = "Recent files",
    key  = "r",
    action = "Telescope oldfiles",
  },
  {
    icon = "  ",
    desc = "Live grep",
    key  = "g",
    action = "Telescope live_grep",
  },
  {
    icon = "  ",
    desc = "File explorer",
    key  = "e",
    action = "Neotree toggle",
  },
  {
    icon = "  ",
    desc = "LazyGit",
    key  = "G",
    action = "LazyGit",
  },
  {
    icon = "  ",
    desc = "Keymaps",
    key  = "k",
    action = "Telescope keymaps",
  },
  {
    icon = "  ",
    desc = "Quit",
    key  = "q",
    action = "qa",
  },
}

-- ── OPTION B setup (uncomment header line below + comment image block) ─────
db.setup({
  theme = "doom",
  config = {
    -- header = ascii_header,   -- OPTION B: uncomment this line
    header = { "", "", "", "", "", "", "", "", "", "", "", "", "", "", "" }, -- spacer for image
    center  = center,
    footer  = function()
      local version = vim.version()
      return {
        "",
        string.format(
          "  Neovim v%d.%d.%d  —  themed by matugen",
          version.major, version.minor, version.patch
        ),
      }
    end,
  },
})

-- ── OPTION A: Render actual PNG image via image.nvim ───────────────────────
-- Comment out this entire block to switch to OPTION B (ASCII art).
local _img_ok, image = pcall(require, "image")
if _img_ok then
  image.setup({
    backend          = "kitty",
    integrations     = {},
    max_width        = nil,
    max_height       = 14,
    max_width_window_percentage  = nil,
    max_height_window_percentage = 50,
    kitty_method     = "normal",
  })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "dashboard",
  once    = false,
  callback = function()
    local ok, image = pcall(require, "image")
    if not ok then return end

    -- Image path is set by neovim.nix via vim.g.naruto_image_path
    local img_path = vim.g.naruto_image_path
    if not img_path or vim.fn.filereadable(img_path) == 0 then return end

    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()

    -- Render image at top of dashboard window
    local img = image.from_file(img_path, {
      buffer             = buf,
      window             = win,
      with_virtual_padding = true,
      x                  = 0,
      y                  = 0,
      height             = 14,  -- rows of terminal cells
    })

    if img then
      img:render()
    end
  end,
})
