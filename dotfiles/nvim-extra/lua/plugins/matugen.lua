-- ================================================================================================
-- TITLE : matugen colorscheme
-- ABOUT : Neovim colorscheme using matugen-generated colors from wallpaper
-- ================================================================================================

local M = {}

function M.setup()
  -- Try to load matugen colors
  local ok, colors = pcall(require, "utils.matugen-colors")
  if not ok then
    -- Fallback: use default colors if matugen hasn't run yet
    return
  end

  -- Clear existing highlights
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end

  vim.g.colors_name = "matugen"

  local hl = vim.api.nvim_set_hl

  -- UI
  hl(0, "Normal",        { fg = colors.on_surface, bg = "NONE" })
  hl(0, "NormalNC",      { fg = colors.on_surface, bg = "NONE" })
  hl(0, "NormalFloat",   { fg = colors.on_surface, bg = colors.surface })
  hl(0, "FloatBorder",   { fg = colors.outline, bg = colors.surface })
  hl(0, "FloatTitle",    { fg = colors.primary, bg = colors.surface })
  hl(0, "SignColumn",    { bg = "NONE" })
  hl(0, "LineNr",        { fg = colors.outline, bg = "NONE" })
  hl(0, "CursorLineNr",  { fg = colors.primary, bg = "NONE" })
  hl(0, "CursorLine",    { bg = colors.surface })
  hl(0, "StatusLine",    { fg = colors.on_surface, bg = colors.surface })
  hl(0, "StatusLineNC",  { fg = colors.on_surface_variant, bg = colors.surface })
  hl(0, "WinSeparator",  { fg = colors.outline, bg = "NONE" })
  hl(0, "VertSplit",     { fg = colors.outline, bg = "NONE" })
  hl(0, "TabLine",       { fg = colors.on_surface_variant, bg = colors.surface })
  hl(0, "TabLineFill",   { bg = colors.surface })
  hl(0, "TabLineSel",    { fg = colors.on_surface, bg = colors.primary })
  hl(0, "Title",         { fg = colors.primary, bold = true })
  hl(0, "EndOfBuffer",   { fg = colors.surface, bg = "NONE" })
  hl(0, "MsgArea",       { fg = colors.on_surface, bg = "NONE" })

  -- Syntax
  hl(0, "Comment",       { fg = colors.on_surface_variant, italic = true })
  hl(0, "Constant",      { fg = colors.tertiary })
  hl(0, "String",        { fg = colors.tertiary })
  hl(0, "Character",     { fg = colors.tertiary })
  hl(0, "Number",        { fg = colors.tertiary })
  hl(0, "Boolean",       { fg = colors.tertiary })
  hl(0, "Float",         { fg = colors.tertiary })
  hl(0, "Identifier",    { fg = colors.primary })
  hl(0, "Function",      { fg = colors.primary })
  hl(0, "Statement",     { fg = colors.secondary })
  hl(0, "Conditional",   { fg = colors.secondary })
  hl(0, "Repeat",        { fg = colors.secondary })
  hl(0, "Label",         { fg = colors.secondary })
  hl(0, "Operator",      { fg = colors.on_surface })
  hl(0, "Keyword",       { fg = colors.secondary })
  hl(0, "Exception",     { fg = colors.secondary })
  hl(0, "PreProc",       { fg = colors.primary })
  hl(0, "Include",       { fg = colors.primary })
  hl(0, "Define",        { fg = colors.primary })
  hl(0, "Macro",         { fg = colors.primary })
  hl(0, "PreCondit",     { fg = colors.primary })
  hl(0, "Type",          { fg = colors.primary })
  hl(0, "StorageClass",  { fg = colors.primary })
  hl(0, "Structure",     { fg = colors.primary })
  hl(0, "Typedef",       { fg = colors.primary })
  hl(0, "Special",       { fg = colors.tertiary })
  hl(0, "SpecialChar",   { fg = colors.tertiary })
  hl(0, "Tag",           { fg = colors.primary })
  hl(0, "Delimiter",     { fg = colors.on_surface })
  hl(0, "SpecialComment",{ fg = colors.on_surface_variant })
  hl(0, "Debug",         { fg = colors.error })
  hl(0, "Underlined",    { underline = true })
  hl(0, "Error",         { fg = colors.error })
  hl(0, "Todo",          { fg = colors.primary, bold = true })

  -- Diagnostics
  hl(0, "DiagnosticError", { fg = colors.error })
  hl(0, "DiagnosticWarn",  { fg = colors.tertiary })
  hl(0, "DiagnosticInfo",  { fg = colors.primary })
  hl(0, "DiagnosticHint",  { fg = colors.on_surface_variant })
  hl(0, "DiagnosticOk",    { fg = colors.secondary })

  -- Git signs
  hl(0, "GitSignsAdd",    { fg = colors.secondary })
  hl(0, "GitSignsChange", { fg = colors.primary })
  hl(0, "GitSignsDelete", { fg = colors.error })

  -- Search
  hl(0, "Search",        { bg = colors.primary, fg = colors.on_primary })
  hl(0, "IncSearch",     { bg = colors.primary, fg = colors.on_primary })
  hl(0, "CurSearch",     { bg = colors.primary, fg = colors.on_primary })

  -- Visual
  hl(0, "Visual",        { bg = colors.primary, fg = colors.on_primary })
  hl(0, "VisualNOS",     { bg = colors.primary, fg = colors.on_primary })

  -- Popup menu
  hl(0, "Pmenu",         { fg = colors.on_surface, bg = colors.surface })
  hl(0, "PmenuSel",      { fg = colors.on_primary, bg = colors.primary })
  hl(0, "PmenuSbar",     { bg = colors.surface })
  hl(0, "PmenuThumb",    { bg = colors.outline })

  -- Cursor
  hl(0, "Cursor",        { fg = colors.on_primary, bg = colors.primary })
  hl(0, "lCursor",       { fg = colors.on_primary, bg = colors.primary })
  hl(0, "CursorIM",      { fg = colors.on_primary, bg = colors.primary })
  hl(0, "CursorColumn",  { bg = colors.surface })

  -- Match parentheses
  hl(0, "MatchParen",    { fg = colors.primary, bold = true })

  -- Diff
  hl(0, "DiffAdd",       { bg = colors.secondary, fg = colors.on_primary })
  hl(0, "DiffChange",    { bg = colors.primary, fg = colors.on_primary })
  hl(0, "DiffDelete",    { bg = colors.error, fg = colors.on_primary })
  hl(0, "DiffText",      { bg = colors.primary, fg = colors.on_primary, bold = true })

  -- Spell
  hl(0, "SpellBad",      { sp = colors.error, undercurl = true })
  hl(0, "SpellCap",      { sp = colors.primary, undercurl = true })
  hl(0, "SpellRare",     { sp = colors.tertiary, undercurl = true })
  hl(0, "SpellLocal",    { sp = colors.secondary, undercurl = true })

  -- Bufferline
  hl(0, "BufferLineFill",              { bg = "NONE" })
  hl(0, "BufferLineBackground",       { fg = colors.on_surface_variant, bg = "NONE" })
  hl(0, "BufferLineBufferVisible",    { fg = colors.on_surface, bg = "NONE" })
  hl(0, "BufferLineBufferSelected",   { fg = colors.primary, bg = "NONE", bold = true })
  hl(0, "BufferLineTab",              { fg = colors.on_surface_variant, bg = "NONE" })
  hl(0, "BufferLineTabSelected",      { fg = colors.primary, bg = "NONE" })
  hl(0, "BufferLineTabClose",         { fg = colors.error, bg = "NONE" })
  hl(0, "BufferLineSeparator",        { fg = colors.outline, bg = "NONE" })
  hl(0, "BufferLineOffsetSeparator",  { fg = colors.outline, bg = "NONE" })

  -- Which-key
  hl(0, "WhichKey",        { fg = colors.primary })
  hl(0, "WhichKeyGroup",   { fg = colors.secondary })
  hl(0, "WhichKeyDesc",    { fg = colors.on_surface })
  hl(0, "WhichKeySeparator",{ fg = colors.outline })
  hl(0, "WhichKeyFloat",   { bg = colors.surface })

  -- Telescope
  hl(0, "TelescopeNormal",      { fg = colors.on_surface, bg = colors.surface })
  hl(0, "TelescopeBorder",      { fg = colors.outline, bg = colors.surface })
  hl(0, "TelescopePromptBorder",{ fg = colors.primary, bg = colors.surface })
  hl(0, "TelescopePromptPrefix",{ fg = colors.primary })
  hl(0, "TelescopeSelection",   { fg = colors.on_primary, bg = colors.primary })
  hl(0, "TelescopeMatching",    { fg = colors.primary, bold = true })

  -- Neo-tree
  hl(0, "NeoTreeNormal",        { fg = colors.on_surface, bg = "NONE" })
  hl(0, "NeoTreeNormalNC",      { fg = colors.on_surface, bg = "NONE" })
  hl(0, "NeoTreeDirectoryName", { fg = colors.primary })
  hl(0, "NeoTreeDirectoryIcon", { fg = colors.primary })
  hl(0, "NeoTreeFileName",      { fg = colors.on_surface })
  hl(0, "NeoTreeGitAdded",      { fg = colors.secondary })
  hl(0, "NeoTreeGitModified",   { fg = colors.primary })
  hl(0, "NeoTreeGitDeleted",    { fg = colors.error })
  hl(0, "NeoTreeGitUntracked",  { fg = colors.on_surface_variant })

  -- LSP
  hl(0, "LspReferenceText",  { bg = colors.surface })
  hl(0, "LspReferenceRead",  { bg = colors.surface })
  hl(0, "LspReferenceWrite", { bg = colors.surface })

  -- Treesitter
  hl(0, "@variable",          { fg = colors.on_surface })
  hl(0, "@variable.builtin",  { fg = colors.primary })
  hl(0, "@property",          { fg = colors.primary })
  hl(0, "@field",             { fg = colors.primary })
  hl(0, "@parameter",         { fg = colors.on_surface })
  hl(0, "@constructor",       { fg = colors.primary })
  hl(0, "@keyword",           { fg = colors.secondary })
  hl(0, "@keyword.function",  { fg = colors.secondary })
  hl(0, "@keyword.return",    { fg = colors.secondary })
  hl(0, "@keyword.operator",  { fg = colors.secondary })
  hl(0, "@type",              { fg = colors.primary })
  hl(0, "@type.builtin",      { fg = colors.primary })
  hl(0, "@function",          { fg = colors.primary })
  hl(0, "@function.builtin",  { fg = colors.primary })
  hl(0, "@string",            { fg = colors.tertiary })
  hl(0, "@number",            { fg = colors.tertiary })
  hl(0, "@boolean",           { fg = colors.tertiary })
  hl(0, "@comment",           { fg = colors.on_surface_variant, italic = true })
  hl(0, "@punctuation",       { fg = colors.on_surface })
  hl(0, "@tag",               { fg = colors.primary })
  hl(0, "@tag.attribute",     { fg = colors.primary })
  hl(0, "@tag.delimiter",     { fg = colors.on_surface })
end

return M
