return {
  -- In-buffer markdown rendering (headings, code blocks, checkboxes, tables)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-mini/mini.icons",
    },
    opts = {
      heading  = { enabled = true },
      code     = { enabled = true },
      bullet   = { enabled = true },
      checkbox = { enabled = true },
      table    = { enabled = true },
    },
  },

  -- Live browser preview
  {
    "iamcco/markdown-preview.nvim",
    cmd  = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft   = { "markdown" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_auto_start   = 0
      vim.g.mkdp_auto_close   = 0
      vim.g.mkdp_echo_preview_url = 1
      vim.g.mkdp_filetypes    = { "markdown" }
    end,
  },

  -- Markdown editing helpers (checkbox toggle, table formatting)
  {
    "tadmccorkle/markdown.nvim",
    ft   = "markdown",
    opts = {
      checkbox = { enabled = true },
      table    = { enabled = true },
    },
    keys = {
      { "<leader>mc", "<Cmd>MarkdownCheckbox<CR>", ft = "markdown", desc = "Toggle Checkbox" },
    },
  },
}
