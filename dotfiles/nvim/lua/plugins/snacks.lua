return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile    = { enabled = true },
    indent     = { enabled = true },
    image      = { enabled = true },
    input      = { enabled = false },
    quickfile  = { enabled = true },
    scope      = { enabled = true },
    scroll     = { enabled = true },
    statuscolumn = { enabled = true },
    words      = { enabled = true },

    notifier = {
      enabled = true,
      timeout = 3000,
    },

    dashboard = {
      enabled = true,
      preset = {
        header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
      },
      sections = {
        { section = "header" },
        { section = "keys",    gap = 1, padding = 1 },
        { section = "startup", icon = " " },
      },
    },

    explorer = {
      enabled = true,
      cwd = vim.g.snacks_explorer_cwd or vim.fn.getcwd(),
    },

    picker = {
      enabled = true,
      confirm = "tab",
      sources = {
        explorer = {
          auto_close = false,
          jump = { close = false },
          hidden = true,
          on_change = function(picker)
            vim.g.snacks_explorer_cwd = picker:cwd()
          end,
          win = {
            list = {
              keys = {
                ["d"] = { "explorer_delete", mode = { "n" } },
                ["f"] = { "explorer_menu",   mode = { "n" } },
              },
            },
          },
          actions = {
            explorer_delete = function(picker)
              local item = picker:current()
              if not item or not item.file or item.file == "" then return end
              local name = vim.fn.fnamemodify(item.file, ":t")
              if vim.fn.confirm("Delete " .. name .. "?", "&Yes\n&No", 2) ~= 1 then return end
              local stat = vim.uv.fs_stat(item.file)
              local ok = stat and stat.type == "directory"
                and pcall(vim.fn.delete, item.file, "rf")
                or  pcall(vim.fn.delete, item.file)
              if ok then
                Snacks.notify.info("Deleted: " .. name, { title = "Explorer" })
                picker:find({})
              else
                Snacks.notify.error("Delete failed", { title = "Explorer" })
              end
            end,

            explorer_menu = function(picker)
              local items = {
                { label = "New file/dir",  action = "explorer_add" },
                { label = "Rename",        action = "explorer_rename" },
                { label = "Copy",          action = "explorer_copy" },
                { label = "Paste",         action = "explorer_paste" },
                { label = "Move",          action = "explorer_move" },
                { label = "Delete",        action = "explorer_del" },
                { label = "Yank path",     action = "explorer_yank" },
                { label = "Open (system)", action = "explorer_open" },
                { label = "Close dir",     action = "explorer_close" },
                { label = "Refresh",       action = "explorer_update" },
              }
              vim.ui.select(items, {
                prompt = "File Menu",
                format_item = function(i) return i.label end,
              }, function(choice)
                if choice then picker:action(choice.action) end
              end)
            end,
          },
        },
      },
    },

    styles = {
      notification = { wo = { wrap = true } },
    },
  },

  keys = {
    -- Explorer & smart finder
    { "<leader>e",       function() Snacks.explorer({ cwd = vim.g.snacks_explorer_cwd }) end, desc = "File Explorer" },
    { "<leader><space>", function() Snacks.picker.smart() end,         desc = "Smart Find Files" },
    { "<leader>,",       function() Snacks.picker.buffers() end,       desc = "Buffers" },
    { "<leader>/",       function() Snacks.picker.grep() end,          desc = "Grep" },
    { "<leader>:",       function() Snacks.picker.command_history() end, desc = "Command History" },
    { "<leader>n",       function() Snacks.picker.notifications() end, desc = "Notifications" },

    -- Find
    { "<leader>ff", function() Snacks.picker.files() end,                               desc = "Find Files" },
    { "<leader>fr", function() Snacks.picker.recent() end,                              desc = "Recent Files" },
    { "<leader>fp", function() Snacks.picker.projects() end,                            desc = "Projects" },
    { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Config Files" },
    { "<leader>fb", function() Snacks.picker.buffers() end,                             desc = "Buffers" },

    -- Search
    { "<leader>sg", function() Snacks.picker.grep() end,                              desc = "Grep" },
    { "<leader>sw", function() Snacks.picker.grep_word() end, mode = { "n", "x" },   desc = "Grep Word" },
    { "<leader>sh", function() Snacks.picker.help() end,                              desc = "Help" },
    { "<leader>sk", function() Snacks.picker.keymaps() end,                           desc = "Keymaps" },
    { "<leader>sd", function() Snacks.picker.diagnostics() end,                       desc = "Diagnostics" },
    { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end,                desc = "Buffer Diagnostics" },
    { "<leader>sR", function() Snacks.picker.resume() end,                            desc = "Resume Picker" },

    -- Git
    { "<leader>gl", function() Snacks.picker.git_log() end,        desc = "Git Log" },
    { "<leader>gs", function() Snacks.picker.git_status() end,     desc = "Git Status" },
    { "<leader>gB", function() Snacks.gitbrowse() end, mode = { "n", "v" }, desc = "Git Browse" },
    { "<leader>gg", function() Snacks.lazygit() end,               desc = "Lazygit" },

    -- LSP (via picker)
    { "gd",  function() Snacks.picker.lsp_definitions() end,      desc = "Go to Definition" },
    { "gD",  function() Snacks.picker.lsp_declarations() end,     desc = "Go to Declaration" },
    { "gr",  function() Snacks.picker.lsp_references() end,       desc = "References" },
    { "gI",  function() Snacks.picker.lsp_implementations() end,  desc = "Go to Implementation" },
    { "gy",  function() Snacks.picker.lsp_type_definitions() end, desc = "Type Definition" },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end,   desc = "LSP Symbols" },
    { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Workspace Symbols" },

    -- Misc
    { "<c-/>",      function() Snacks.terminal() end,               desc = "Terminal" },
    { "<leader>z",  function() Snacks.zen() end,                    desc = "Zen Mode" },
    { "<leader>Z",  function() Snacks.zen.zoom() end,               desc = "Zoom" },
    { "<leader>.",  function() Snacks.scratch() end,                desc = "Scratch Buffer" },
    { "<leader>bd", function() Snacks.bufdelete() end,             desc = "Delete Buffer" },
    { "<leader>cR", function() Snacks.rename.rename_file() end,    desc = "Rename File" },
    { "<leader>un", function() Snacks.notifier.hide() end,         desc = "Dismiss Notifications" },
    { "]]", function() Snacks.words.jump(vim.v.count1) end,  mode = { "n", "t" }, desc = "Next Reference" },
    { "[[", function() Snacks.words.jump(-vim.v.count1) end, mode = { "n", "t" }, desc = "Prev Reference" },
  },

  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        Snacks.toggle.option("spell",          { name = "Spelling" }):map("<leader>Ss")
        Snacks.toggle.option("wrap",           { name = "Wrap" }):map("<leader>Sw")
        Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>SL")
        Snacks.toggle.diagnostics():map("<leader>Sd")
        Snacks.toggle.line_number():map("<leader>Sl")
        Snacks.toggle.treesitter():map("<leader>ST")
        Snacks.toggle.indent():map("<leader>Sg")
        Snacks.toggle.dim():map("<leader>SD")
        Snacks.toggle.inlay_hints():map("<leader>Sh")
      end,
    })
  end,
}
