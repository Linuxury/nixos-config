 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#131319',
    base01 = '#1f1f26',
    base02 = '#292930',
    base03 = '#908f9e',
    base04 = '#c6c5d5',
    base05 = '#e4e1eb',
    base06 = '#e4e1eb',
    base07 = '#e4e1eb',
    base08 = '#ffb4ab',
    base09 = '#f4aeff',
    base0A = '#c0c3f2',
    base0B = '#bdc2ff',
    base0C = '#f4aeff',
    base0D = '#bdc2ff',
    base0E = '#c0c3f2',
    base0F = '#93000a',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  hi('TelescopeNormal',         { fg = '#e4e1eb',          bg = '#131319' })
  hi('TelescopeBorder',         { fg = '#908f9e',             bg = '#131319' })
  hi('TelescopePromptNormal',   { fg = '#e4e1eb',          bg = '#131319' })
  hi('TelescopePromptBorder',   { fg = '#908f9e',             bg = '#131319' })
  hi('TelescopePromptPrefix',   { fg = '#bdc2ff',             bg = '#131319' })
  hi('TelescopePromptCounter',  { fg = '#c6c5d5',  bg = '#131319' })
  hi('TelescopePromptTitle',    { fg = '#131319',             bg = '#bdc2ff' })
  hi('TelescopePreviewTitle',   { fg = '#131319',             bg = '#c0c3f2' })
  hi('TelescopeResultsTitle',   { fg = '#131319',             bg = '#f4aeff' })
  hi('TelescopeSelection',      { fg = '#e4e1eb',          bg = '#292930' })
  hi('TelescopeSelectionCaret', { fg = '#bdc2ff',             bg = '#292930' })
  hi('TelescopeMatching',       { fg = '#bdc2ff',             bold = true })
end

 -- Register a signal handler for SIGUSR1 (matugen updates)
 local signal = vim.uv.new_signal()
 signal:start(
   'sigusr1',
   vim.schedule_wrap(function()
     package.loaded['matugen'] = nil
     require('matugen').setup()
   end)
 )

 return M
