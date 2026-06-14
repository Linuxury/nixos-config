return {
  -- LSP client — binaries come from Nix, not Mason
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" },
    config = function()
      require("utils.diagnostics").setup()
      require("servers")
    end,
  },

  -- Autocomplete
  {
    "saghen/blink.cmp",
    event = "InsertEnter",
    version = "1.*",
    dependencies = {
      {
        "L3MON4D3/LuaSnip",
        version = "2.*",
        dependencies = { "rafamadriz/friendly-snippets" },
        config = function()
          require("luasnip.loaders.from_vscode").lazy_load()
        end,
      },
      "folke/lazydev.nvim",
    },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        preset  = "default",
        ["<CR>"]    = { "accept", "fallback" },
        ["<Tab>"]   = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 500 },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "lazydev" },
        providers = {
          lazydev = { module = "lazydev.integrations.blink", score_offset = 100 },
        },
      },
      snippets   = { preset = "luasnip" },
      fuzzy      = { implementation = "prefer_rust_with_warning" },
      signature  = { enabled = true },
    },
  },

  -- Lua LSP type hints for Neovim APIs (resolves vim.* undefined-global warnings)
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library",  words = { "vim%.uv" } },
        { path = "snacks.nvim",         words = { "Snacks", "snacks%.Config" } },
      },
    },
  },
}
