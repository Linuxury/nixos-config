return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "bash", "c", "cmake", "css", "dockerfile",
          "fish", "go", "gitignore", "html", "java",
          "javascript", "json", "lua", "make",
          "markdown", "markdown_inline", "nix",
          "python", "regex", "rust", "sql",
          "toml", "tsx", "typescript",
          "vim", "vimdoc", "yaml",
        },
        auto_install = true,
        highlight   = { enable = true },
        indent      = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection    = "<c-space>",
            node_incremental  = "<c-space>",
            scope_incremental = "<c-s>",
            node_decremental  = "<M-space>",
          },
        },
        textobjects = {
          select = {
            enable    = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
              ["aa"] = "@parameter.outer",
              ["ia"] = "@parameter.inner",
            },
          },
          move = {
            enable     = true,
            set_jumps  = true,
            goto_next_start     = { ["]m"] = "@function.outer", ["]]"] = "@class.outer" },
            goto_next_end       = { ["]M"] = "@function.outer", ["]["] = "@class.outer" },
            goto_previous_start = { ["[m"] = "@function.outer", ["[["] = "@class.outer" },
            goto_previous_end   = { ["[M"] = "@function.outer", ["[]"] = "@class.outer" },
          },
        },
      })
    end,
  },
}
