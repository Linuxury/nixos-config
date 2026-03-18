require("which-key").setup({
  delay = 500,
  icons = { mappings = false },  -- no icons, cleaner with terminal colors
  win = {
    border = "single",
    wo = { winblend = 0 },
  },
})

-- <leader>? opens the full keybind map explicitly
vim.keymap.set("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer keybinds" })
