-- ================================================================================================
-- TITLE : opencode.nvim
-- ABOUT : Neovim integration for the opencode AI coding agent
-- LINKS :
--   > opencode-nvim : https://github.com/NickvanDyke/opencode.nvim
--   > opencode CLI  : https://github.com/sst/opencode
-- ================================================================================================

return {
  'nickjvandyke/opencode.nvim',
  version = '*',
  event = 'VeryLazy',
  dependencies = {
    {
      'folke/snacks.nvim',
      optional = true,
      opts = {
        input = {},
        picker = {
          actions = {
            opencode_send = function(...) return require('opencode').snacks_picker_send(...) end,
          },
          win = {
            input = {
              keys = {
                ['<a-a>'] = { 'opencode_send', mode = { 'n', 'i' } },
              },
            },
          },
        },
      },
    },
  },
  config = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {}

    vim.o.autoread = true

    -- Toggle opencode panel
    vim.keymap.set({ 'n', 't' }, '<leader>ao', function() require('opencode').toggle() end, { desc = 'Toggle opencode' })

    -- Ask with context (visual selection or cursor position)
    vim.keymap.set({ 'n', 'x' }, '<leader>aa', function()
      require('opencode').ask('@this: ', { submit = true })
    end, { desc = 'Ask opencode (context)' })

    -- Select from prompt library
    vim.keymap.set({ 'n', 'x' }, '<leader>ax', function() require('opencode').select() end, { desc = 'opencode: select action' })

    -- Send operator range to opencode (go + motion, e.g. goip for inner paragraph)
    vim.keymap.set({ 'n', 'x' }, 'go', function()
      return require('opencode').operator('@this ')
    end, { desc = 'Send range to opencode', expr = true })
    vim.keymap.set('n', 'goo', function()
      return require('opencode').operator('@this ') .. '_'
    end, { desc = 'Send line to opencode', expr = true })

    -- Scroll opencode panel without leaving buffer
    vim.keymap.set('n', '<leader>au', function() require('opencode').command('session.half.page.up') end, { desc = 'opencode: scroll up' })
    vim.keymap.set('n', '<leader>ad', function() require('opencode').command('session.half.page.down') end, { desc = 'opencode: scroll down' })

    -- Disable trailing-space dots (listchars) in the opencode terminal panel
    vim.api.nvim_create_autocmd('TermOpen', {
      pattern = 'term://*opencode*',
      callback = function() vim.wo.list = false end,
    })
  end,
}
