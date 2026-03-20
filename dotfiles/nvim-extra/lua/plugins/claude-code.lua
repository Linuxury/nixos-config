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
      window = {
        position        = 'botright vertical',
        split_ratio     = 0.35,
        enter_insert    = true,
        hide_numbers    = true,
        hide_signcolumn = true,
      },
      refresh = {
        enable             = true,
        updatetime         = 100,
        timer_interval     = 1000,
        show_notifications = true,
      },
      git = { use_git_root = true },
      -- Disable built-in keymaps — we define our own float toggle below
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
    -- Custom float toggle — opens Claude Code in a floating window so it
    -- never disrupts the editor layout when opened or closed.
    -- -----------------------------------------------------------------------
    local cc_state = { bufnr = nil, winid = nil }

    local function claude_float_toggle(extra_args)
      -- Close if already visible
      if cc_state.winid and vim.api.nvim_win_is_valid(cc_state.winid) then
        vim.api.nvim_win_close(cc_state.winid, true)
        cc_state.winid = nil
        return
      end

      local width  = math.floor(vim.o.columns * 0.42)
      local height = math.floor(vim.o.lines   * 0.88)
      local col    = vim.o.columns - width - 2
      local row    = math.floor((vim.o.lines - height) / 2)

      local win_opts = {
        relative = 'editor',
        width    = width,
        height   = height,
        col      = col,
        row      = row,
        style    = 'minimal',
        border   = 'rounded',
        title    = ' Claude Code ',
        title_pos = 'center',
      }

      -- Reuse existing buffer if still valid
      if cc_state.bufnr and vim.api.nvim_buf_is_valid(cc_state.bufnr) then
        cc_state.winid = vim.api.nvim_open_win(cc_state.bufnr, true, win_opts)
        vim.cmd 'startinsert'
        return
      end

      -- Create new buffer + terminal
      local bufnr = vim.api.nvim_create_buf(false, true)
      cc_state.winid = vim.api.nvim_open_win(bufnr, true, win_opts)

      local cmd = 'claude'
      if extra_args then cmd = cmd .. ' ' .. extra_args end

      -- cd to git root if available
      local git = require('claude-code.git')
      local root = git and git.get_git_root and git.get_git_root()
      if root then
        cmd = 'pushd ' .. root .. ' && ' .. cmd .. ' && popd'
      end

      vim.fn.termopen(cmd, {
        on_exit = function()
          cc_state.bufnr = nil
          cc_state.winid = nil
        end,
      })

      cc_state.bufnr = bufnr
      vim.bo[bufnr].bufhidden = 'hide'
      vim.wo.number         = false
      vim.wo.relativenumber = false
      vim.wo.signcolumn     = 'no'
      vim.wo.list           = false
      vim.cmd 'startinsert'

      -- Close float on <Esc> or <leader>ac from terminal mode
      vim.keymap.set('t', '<Esc>', function()
        if cc_state.winid and vim.api.nvim_win_is_valid(cc_state.winid) then
          vim.api.nvim_win_close(cc_state.winid, true)
          cc_state.winid = nil
        end
      end, { buffer = bufnr, desc = 'Close Claude Code float' })
    end

    vim.keymap.set('n', '<leader>ac',  function() claude_float_toggle() end,            { desc = 'Toggle Claude Code' })
    vim.keymap.set('t', '<leader>ac',  function() claude_float_toggle() end,            { desc = 'Toggle Claude Code' })
    vim.keymap.set('n', '<leader>acC', function() claude_float_toggle('--continue') end, { desc = 'Claude Code --continue' })
    vim.keymap.set('n', '<leader>acR', function() claude_float_toggle('--resume') end,   { desc = 'Claude Code --resume' })
    vim.keymap.set('n', '<leader>acV', function() claude_float_toggle('--verbose') end,  { desc = 'Claude Code --verbose' })
  end,
}
