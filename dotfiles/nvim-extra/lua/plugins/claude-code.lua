-- ================================================================================================
-- TITLE : claude-code.nvim
-- ABOUT : Neovim integration for the Claude Code AI assistant
-- LINKS :
--   > claude-code-nvim : https://github.com/greggh/claude-code.nvim
--   > claude-code CLI  : https://github.com/anthropics/claude-code
-- ================================================================================================

return {
  'greggh/claude-code.nvim',
  version = '*',
  event = 'VeryLazy',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('claude-code').setup({
      window = {
        position    = 'vertical',  -- right-side vertical split
        split_ratio = 0.35,
        enter_insert   = true,
        hide_numbers   = true,
        hide_signcolumn = true,
      },
      refresh = {
        enable             = true,
        updatetime         = 100,
        timer_interval     = 1000,
        show_notifications = true,
      },
      git = { use_git_root = true },
      keymaps = {
        toggle = {
          normal   = '<leader>ac',
          terminal = '<leader>ac',
          variants = {
            continue = '<leader>acC',
            resume   = '<leader>acR',
            verbose  = '<leader>acV',
          },
        },
        window_navigation = true,
        scrolling         = true,
      },
    })

    -- Disable trailing-space dots (listchars) in the Claude Code terminal panel
    vim.api.nvim_create_autocmd('TermOpen', {
      pattern = 'term://*claude*',
      callback = function() vim.wo.list = false end,
    })
  end,
}
