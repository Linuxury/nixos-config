-- ── Header variants — uncomment the one you want ─────────────────────────────

-- Variant A: Large block — NEOVIM (active)
local header = {
  "",
  "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
  "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
  "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
  "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
  "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
  "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
  "",
}

-- Variant B: Thin outline — NEOVIM
-- local header = {
--   "",
--   "  ╔╗╔╔═╗╔═╗╦  ╦╦╔╦╗",
--   "  ║║║║╣ ║ ║╚╗╔╝║║║║",
--   "  ╝╚╝╚═╝╚═╝ ╚╝ ╩╩ ╩",
--   "",
-- }

-- Variant C: ASCII classic — NEOVIM
-- local header = {
--   "",
--   "  _   _ ___  _____  _   __ ___ __  __",
--   "  | \\ | | __||  _  || | / /|_ _||  \\/  |",
--   "  |  \\| | _|  | | | || |/ /  | | | |\\/| |",
--   "  | |\\  | |__ | |_| ||   /   | | | |  | |",
--   "  |_| \\_|____||_____/|_|\\_\\  |___||_|  |_|",
--   "",
-- }

-- Variant D: Slant — NEOVIM
-- local header = {
--   "",
--   "   _  _____________ _    ________  ___",
--   "  / |/ / __/ __ \\ \\/ /  /  _/ \\/  |/ /",
--   " /    / _// /_/ /\\  /  _/ //    /    / ",
--   "/_/|_/___/\\____/ /_/  /___/_/|_/_/|_/  ",
--   "",
-- }

-- ── Keybind table — fixed-width columns so centering stays aligned ────────────
-- Each row is exactly 76 chars so dashboard centers all lines identically.
local function row(k1, d1, k2, d2)
  return string.format("  %-10s %-26s  %-10s %-24s", k1, d1, k2, d2)
end
local function section(s1, s2)
  return string.format("  %-36s  %-36s", s1, s2)
end
local sep = "  " .. string.rep("─", 72)

local footer = {
  "",
  sep,
  "  Keybindings",
  sep,
  "",
  section("NAVIGATION", "LSP"),
  row("SPC ff",  "Find file",             "gd",      "Go to definition"),
  row("SPC fg",  "Live grep",             "gr",      "References"),
  row("SPC fr",  "Recent files",          "K",       "Hover docs"),
  row("SPC fb",  "Open buffers",          "SPC rn",  "Rename symbol"),
  row("SPC /",   "Fuzzy in buffer",       "SPC ca",  "Code action"),
  row("",        "",                      "[d  ]d",  "Prev / next diagnostic"),
  "",
  section("BUFFERS & SPLITS", "GIT"),
  row("Shift-l", "Next buffer",           "]h  [h",  "Next / prev hunk"),
  row("Shift-h", "Prev buffer",           "SPC gs",  "Stage hunk"),
  row("SPC bd",  "Delete buffer",         "SPC gr",  "Reset hunk"),
  row("SPC sv",  "Vertical split",        "SPC gb",  "Blame line"),
  row("SPC sh",  "Horizontal split",      "SPC gB",  "Toggle line blame"),
  row("SPC sc",  "Close split",           "SPC gx",  "Diff this"),
  "",
  section("LAYOUT", "MISC"),
  row("SPC e",   "Explorer + Claude",     "SPC w",   "Save file"),
  row("SPC cc",  "Toggle Claude Code",    "SPC q",   "Quit"),
  row("SPC cs",  "Send selection",        "SPC tw",  "Toggle word wrap"),
  row("C-h/j/k/l", "Navigate windows",   "SPC ts",  "Toggle spell check"),
  "",
  sep,
  "",
}

require("dashboard").setup({
  theme = "doom",
  config = {
    header = header,
    center = {
      { icon = "  ", key = "SPC e",  desc = "File Explorer",  action = "Neotree show" },
      { icon = "  ", key = "SPC ff", desc = "Find File",      action = "Telescope find_files" },
      { icon = "  ", key = "SPC fr", desc = "Recent Files",   action = "Telescope oldfiles" },
      { icon = "  ", key = "SPC q",  desc = "Quit",           action = "qa" },
    },
    footer = footer,
  },
})
