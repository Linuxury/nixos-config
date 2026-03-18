require("bufferline").setup({
  options = {
    mode             = "buffers",
    separator_style  = "slant",
    show_buffer_close_icons = true,
    show_close_icon         = false,
    always_show_bufferline  = true,
    offsets = {
      {
        filetype  = "neo-tree",
        text      = " Files",
        separator = true,
        highlight = "Directory",
      },
    },
    custom_filter = function(buf)
      -- Exclude terminal buffers (Claude Code, shell panels)
      return vim.bo[buf].buftype ~= "terminal"
    end,
  },
})

-- Navigate tabs with existing Shift-h / Shift-l keymaps (already in keymaps.lua)
-- Close current buffer without closing the window (preserves layout)
vim.keymap.set("n", "<leader>bd", function()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  if #bufs > 1 then
    vim.cmd("bprevious")
  end
  vim.cmd("bdelete #")
end, { desc = "Delete buffer (preserve layout)" })
