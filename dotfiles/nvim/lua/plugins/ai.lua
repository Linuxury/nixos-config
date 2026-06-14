return {
  -- opencode — terminal AI agent with TUI; integrates with snacks picker
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = {
      {
        "folke/snacks.nvim",
        optional = true,
        opts = {
          picker = {
            actions = {
              opencode_send = function(...) return require("opencode").snacks_picker_send(...) end,
            },
            win = {
              input = { keys = { ["<a-a>"] = { "opencode_send", mode = { "n", "i" } } } },
            },
          },
        },
      },
    },
    config = function()
      vim.o.autoread = true

      vim.keymap.set({ "n", "t" }, "<leader>ao", function() require("opencode").toggle() end,                { desc = "Toggle opencode" })
      vim.keymap.set({ "n", "x" }, "<leader>aa", function() require("opencode").ask("@this: ", { submit = true }) end, { desc = "Ask opencode" })
      vim.keymap.set({ "n", "x" }, "<leader>ax", function() require("opencode").select() end,               { desc = "opencode actions" })
      vim.keymap.set("n",          "<leader>au", function() require("opencode").command("session.half.page.up") end,   { desc = "opencode scroll up" })
      vim.keymap.set("n",          "<leader>ad", function() require("opencode").command("session.half.page.down") end, { desc = "opencode scroll down" })

      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*opencode*",
        callback = function()
          vim.wo.list           = false
          vim.wo.cursorline     = false
          vim.wo.signcolumn     = "no"
          vim.wo.number         = false
          vim.wo.relativenumber = false
          pcall(vim.treesitter.stop, 0)
        end,
      })
    end,
  },

  -- Claude Code — sidebar integration
  {
    "greggh/claude-code.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("claude-code").setup({
        window  = { position = "botright vertical", split_ratio = 0.35 },
        refresh = { enable = true, updatetime = 100, timer_interval = 1000, show_notifications = true },
        git     = { use_git_root = true },
        keymaps = { toggle = { normal = false, terminal = false, variants = {} },
                    window_navigation = true, scrolling = true },
      })

      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*claude*",
        callback = function() vim.wo.list = false end,
      })

      local state = { bufnr = nil }
      local function claude_toggle(extra_args)
        local wins = state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)
          and vim.fn.win_findbuf(state.bufnr) or {}
        if #wins > 0 then
          for _, w in ipairs(wins) do vim.api.nvim_win_close(w, true) end
          return
        end
        local width = math.floor(vim.o.columns * 0.38)
        if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
          vim.cmd("botright vertical " .. width .. "split")
          vim.cmd("buffer " .. state.bufnr)
          vim.cmd("vertical resize " .. width)
          vim.cmd("startinsert")
          return
        end
        vim.cmd("botright vertical " .. width .. "split")
        vim.cmd("enew")
        local bufnr = vim.api.nvim_get_current_buf()
        state.bufnr = bufnr
        local cmd = "claude" .. (extra_args and (" " .. extra_args) or "")
        local git = require("claude-code.git")
        local root = git and git.get_git_root and git.get_git_root()
        if root then cmd = "pushd " .. root .. " && " .. cmd .. " && popd" end
        vim.fn.termopen(cmd, { on_exit = function() state.bufnr = nil end })
        vim.cmd("vertical resize " .. width)
        vim.bo[bufnr].bufhidden = "hide"
        vim.wo.number = false; vim.wo.relativenumber = false
        vim.wo.signcolumn = "no"; vim.wo.list = false
        vim.cmd("startinsert")
      end

      vim.keymap.set({ "n", "t" }, "<leader>ac",  function() claude_toggle() end,             { desc = "Toggle Claude Code" })
      vim.keymap.set("n",          "<leader>acC",  function() claude_toggle("--continue") end, { desc = "Claude --continue" })
      vim.keymap.set("n",          "<leader>acR",  function() claude_toggle("--resume") end,   { desc = "Claude --resume" })
    end,
  },
}
