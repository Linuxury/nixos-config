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
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('claude-code').setup({
      -- Disable built-in toggle — we use our own sidebar implementation
      window = { position = 'botright vertical', split_ratio = 0.35 },
      refresh = {
        enable             = true,
        updatetime         = 100,
        timer_interval     = 1000,
        show_notifications = true,
      },
      git = { use_git_root = true },
      keymaps = {
        toggle = { normal = false, terminal = false, variants = {} },
        window_navigation = true,
        scrolling         = true,
      },
    })

    -- Disable trailing-space dots (listchars) in the Claude Code terminal panel
    vim.api.nvim_create_autocmd('TermOpen', {
      pattern = 'term://*claude*',
      callback = function() vim.wo.list = false end,
    })

    -- -----------------------------------------------------------------------
    -- Sidebar toggle — opens Claude Code as a fixed-width right sidebar,
    -- same behaviour as the snacks file explorer on the left.
    -- -----------------------------------------------------------------------
    local SIDEBAR_WIDTH = math.floor(vim.o.columns * 0.38)
    local state = { bufnr = nil }

    local function claude_sidebar_toggle(extra_args)
      -- Close if already visible
      local wins = state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)
        and vim.fn.win_findbuf(state.bufnr) or {}
      if #wins > 0 then
        for _, w in ipairs(wins) do
          vim.api.nvim_win_close(w, true)
        end
        return
      end

      -- Recalculate width each open (in case terminal was resized)
      SIDEBAR_WIDTH = math.floor(vim.o.columns * 0.38)

      -- Reuse existing buffer (process still running)
      if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
        vim.cmd('botright vertical ' .. SIDEBAR_WIDTH .. 'split')
        vim.cmd('buffer ' .. state.bufnr)
        vim.cmd('vertical resize ' .. SIDEBAR_WIDTH)
        vim.cmd 'startinsert'
        return
      end

      -- Create new sidebar + terminal
      vim.cmd('botright vertical ' .. SIDEBAR_WIDTH .. 'split')
      vim.cmd 'enew'

      local bufnr = vim.api.nvim_get_current_buf()
      state.bufnr = bufnr

      local cmd = 'claude'
      if extra_args then cmd = cmd .. ' ' .. extra_args end

      local git = require('claude-code.git')
      local root = git and git.get_git_root and git.get_git_root()
      if root then
        cmd = 'pushd ' .. root .. ' && ' .. cmd .. ' && popd'
      end

      vim.fn.termopen(cmd, {
        on_exit = function()
          state.bufnr = nil
        end,
      })

      vim.cmd('vertical resize ' .. SIDEBAR_WIDTH)
      vim.bo[bufnr].bufhidden = 'hide'
      vim.wo.number         = false
      vim.wo.relativenumber = false
      vim.wo.signcolumn     = 'no'
      vim.wo.list           = false
      vim.cmd 'startinsert'
    end

    vim.keymap.set({ 'n', 't' }, '<leader>ac',  function() claude_sidebar_toggle() end,             { desc = 'Toggle Claude Code' })
    vim.keymap.set('n',          '<leader>acC',  function() claude_sidebar_toggle('--continue') end, { desc = 'Claude Code --continue' })
    vim.keymap.set('n',          '<leader>acR',  function() claude_sidebar_toggle('--resume') end,   { desc = 'Claude Code --resume' })
    vim.keymap.set('n',          '<leader>acV',  function() claude_sidebar_toggle('--verbose') end,  { desc = 'Claude Code --verbose' })
  end,
}
