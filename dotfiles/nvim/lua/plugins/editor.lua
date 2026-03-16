-- ============================================================
-- Editor helpers
-- ── nvim-autopairs     auto-close brackets/quotes
-- ── Comment.nvim       gcc / gc to comment
-- ── nvim-surround      add/change/delete surrounding chars
-- ── nvim-ts-autotag    auto-close HTML/JSX tags
-- ── indent-blankline   indent guide lines
-- ── flash.nvim         jump anywhere in 2 keystrokes
-- ── harpoon            pin hot files for instant switching
-- ── nvim-scrollbar     scrollbar with git/diagnostic markers
-- ── dressing.nvim      prettier input/select UI
-- ============================================================

-- ── Autopairs ─────────────────────────────────────────────
require("nvim-autopairs").setup({
  check_ts         = true,   -- use treesitter to avoid pairing in strings/comments
  ts_config        = {
    lua  = { "string", "source" },
    javascript = { "string", "template_string" },
  },
  fast_wrap        = {
    map            = "<M-e>",
    chars          = { "{", "[", "(", '"', "'" },
    pattern        = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
    end_key        = "$",
    keys           = "qwertyuiopzxcvbnmasdfghjkl",
    check_comma    = true,
    highlight      = "PmenuSel",
    highlight_grey = "LineNr",
  },
})

-- ── Comment.nvim ──────────────────────────────────────────
-- gcc = toggle line comment
-- gc  = toggle comment (visual / motion)
-- gbc = toggle block comment
require("Comment").setup({
  padding     = true,
  sticky      = true,
  ignore      = nil,
  toggler     = { line = "gcc", block = "gbc" },
  opleader    = { line = "gc",  block = "gb"  },
  extra       = { above = "gcO", below = "gco", eol = "gcA" },
  mappings    = { basic = true, extra = true },
  pre_hook    = nil,
  post_hook   = nil,
})

-- ── nvim-surround ─────────────────────────────────────────
-- ys<motion><char>  — add surround
-- ds<char>          — delete surround
-- cs<old><new>      — change surround
-- Example: ysiw" surrounds word with quotes, cs"' changes " to '
require("nvim-surround").setup({
  keymaps = {
    insert          = "<C-g>s",
    insert_line     = "<C-g>S",
    normal          = "ys",
    normal_cur      = "yss",
    normal_line     = "yS",
    normal_cur_line = "ySS",
    visual          = "S",
    visual_line     = "gS",
    delete          = "ds",
    change          = "cs",
    change_line     = "cS",
  },
})

-- ── nvim-ts-autotag ───────────────────────────────────────
require("nvim-ts-autotag").setup({
  opts = {
    enable_close         = true,
    enable_rename        = true,
    enable_close_on_slash = false,
  },
})

-- ── Indent Blankline ──────────────────────────────────────
require("ibl").setup({
  indent = {
    char      = "│",
    tab_char  = "│",
  },
  scope = {
    enabled           = true,
    show_start        = true,
    show_end          = false,
    injected_languages = false,
    highlight         = { "IblScope" },
    priority          = 500,
  },
  exclude = {
    filetypes = {
      "help", "dashboard", "neo-tree", "Trouble", "trouble",
      "lazy", "mason", "notify", "toggleterm", "lazyterm",
    },
  },
})

-- ── Flash.nvim — motion jumping ───────────────────────────
-- s  = flash jump (2-char search across screen)
-- S  = flash treesitter (jump to treesitter node)
-- r  = remote flash (in operator pending mode)
-- R  = treesitter search
-- ;  = toggle search
require("flash").setup({
  labels        = "asdfghjklqwertyuiopzxcvbnm",
  search        = {
    multi_window    = true,
    forward         = true,
    wrap            = true,
    mode            = "exact",
    incremental     = false,
  },
  jump = {
    jumplist    = true,
    pos         = "start",
    history     = false,
    register    = false,
    nohlsearch  = false,
    autojump    = false,
  },
  label = {
    uppercase   = false,
    exclude     = "",
    current     = true,
    after       = true,
    before      = false,
    style       = "overlay",
    reuse       = "lowercase",
    distance    = true,
    min_pattern_length = 0,
    rainbow     = { enabled = false, shade = 5 },
  },
  highlight = {
    backdrop    = true,
    matches     = true,
    priority    = 5000,
    groups      = {
      match     = "FlashMatch",
      current   = "FlashCurrent",
      backdrop  = "FlashBackdrop",
      label     = "FlashLabel",
    },
  },
  modes = {
    search = {
      enabled     = false,   -- don't auto-trigger in /
      highlight   = { backdrop = false },
      jump        = { history = true, register = true, nohlsearch = true },
    },
    char = {
      enabled     = true,
      config      = nil,
      autohide    = false,
      jump_labels = false,
      multi_line  = true,
      label       = { exclude = "hjkliardc" },
      keys        = { "f", "F", "t", "T", ";", "," },
    },
    treesitter = { labels = "abcdefghijklmnopqrstuvwxyz" },
    treesitter_search = {
      jump        = { pos = "range" },
      search      = { multi_window = true, wrap = true, incremental = false },
      remote_op   = { restore = true, motion = true },
      label       = { before = true, after = true, style = "inline" },
    },
    remote = { remote_op = { restore = true, motion = true } },
  },
})

-- Flash keymaps
vim.keymap.set({ "n", "x", "o" }, "s",  function() require("flash").jump() end,             { desc = "Flash jump" })
vim.keymap.set({ "n", "x", "o" }, "S",  function() require("flash").treesitter() end,        { desc = "Flash treesitter" })
vim.keymap.set("o",               "r",  function() require("flash").remote() end,             { desc = "Remote flash" })
vim.keymap.set({ "o", "x" },      "R",  function() require("flash").treesitter_search() end,  { desc = "Treesitter search" })
vim.keymap.set("c",               "<c-s>", function() require("flash").toggle() end,          { desc = "Toggle flash search" })

-- ── Harpoon ───────────────────────────────────────────────
-- Configured in keymaps.lua: <leader>h*
local harpoon = require("harpoon")
harpoon:setup({
  settings = {
    save_on_toggle   = false,
    sync_on_ui_close = false,
    key              = function()
      return vim.loop.cwd()
    end,
  },
})

-- ── Scrollbar ─────────────────────────────────────────────
require("scrollbar").setup({
  show              = true,
  show_in_active_only = false,
  set_highlights    = true,
  folds             = 1000,
  max_lines         = false,
  hide_if_all_visible = true,
  throttle_ms       = 100,
  handle = {
    text      = " ",
    blend     = 30,
    color     = nil,
    color_nr  = nil,
    highlight = "CursorColumn",
    hide_if_all_visible = true,
  },
  marks = {
    GitAdd    = { text = "│" },
    GitChange = { text = "│" },
    GitDelete = { text = "▁" },
    Misc      = { text = "│" },
    Search    = { text = { "-", "=" } },
    Error     = { text = { "-", "=" } },
    Warn      = { text = { "-", "=" } },
    Info      = { text = { "-", "=" } },
    Hint      = { text = { "-", "=" } },
  },
  excluded_buftypes  = { "terminal" },
  excluded_filetypes = { "dropbar_menu", "dropbar_menu_fzf", "DressingInput", "cmp_docs", "cmp_menu", "noice", "prompt", "TelescopePrompt" },
  autocmd = {
    render = { "BufWinEnter", "TabEnter", "TermEnter", "WinEnter", "CmdwinLeave", "TextChanged", "VimResized", "WinScrolled" },
    clear   = { "BufWinLeave", "TabLeave", "TermLeave", "WinLeave" },
  },
  handlers = {
    cursor     = true,
    diagnostic = true,
    gitsigns   = true,
    handle     = true,
    search     = false,
    ale        = false,
  },
})

-- ── Dressing.nvim — prettier UI dialogs ───────────────────
require("dressing").setup({
  input = {
    enabled          = true,
    default_prompt   = "Input:",
    trim_prompt      = true,
    border           = "rounded",
    relative         = "cursor",
    prefer_width     = 40,
    width            = nil,
    max_width        = { 140, 0.9 },
    min_width        = { 20, 0.2 },
    win_options      = {
      wrap     = false,
      list     = true,
      listchars = "precedes:…,extends:…",
      sidescrolloff = 0,
    },
    mappings         = {
      n = { ["<Esc>"] = "Close", ["<CR>"] = "Confirm" },
      i = {
        ["<C-c>"] = "Close",
        ["<CR>"]  = "Confirm",
        ["<Up>"]  = "HistoryPrev",
        ["<Down>"] = "HistoryNext",
      },
    },
  },
  select = {
    enabled   = true,
    backend   = { "telescope", "fzf_lua", "fzf", "builtin", "nui" },
    trim_prompt = true,
  },
})
