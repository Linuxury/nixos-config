return {
  -- mini.nvim modules — lightweight, no external dependencies
  { "echasnovski/mini.ai",        version = false, event = "VeryLazy", opts = {} },
  { "echasnovski/mini.comment",   version = false, event = "VeryLazy", opts = {} },
  { "echasnovski/mini.surround",  version = false, event = "VeryLazy", opts = {} },
  { "echasnovski/mini.pairs",     version = false, event = "VeryLazy", opts = {} },
  { "echasnovski/mini.move",      version = false, event = "VeryLazy", opts = {} },
  { "echasnovski/mini.cursorword",version = false, event = "VeryLazy", opts = {} },
  { "echasnovski/mini.trailspace",version = false, event = "VeryLazy", opts = {} },

  -- Icons (mock nvim-web-devicons so other plugins pick them up automatically)
  {
    "nvim-mini/mini.icons",
    lazy = true,
    opts = {},
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- Git gutter indicators + hunk navigation
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
        untracked    = { text = "▎" },
      },
      on_attach = function(buf)
        local gs = package.loaded.gitsigns
        local map = function(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buf, desc = desc, silent = true })
        end

        map("n", "]h", function() if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) else gs.nav_hunk("next") end end, "Next Hunk")
        map("n", "[h", function() if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) else gs.nav_hunk("prev") end end, "Prev Hunk")
        map({ "n", "x" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>",  "Stage Hunk")
        map({ "n", "x" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>",  "Reset Hunk")
        map("n", "<leader>ghS", gs.stage_buffer,                       "Stage Buffer")
        map("n", "<leader>ghu", gs.undo_stage_hunk,                    "Undo Stage Hunk")
        map("n", "<leader>ghR", gs.reset_buffer,                       "Reset Buffer")
        map("n", "<leader>ghp", gs.preview_hunk_inline,                "Preview Hunk")
        map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame Line")
        map("n", "<leader>ghd", gs.diffthis,                           "Diff This")
      end,
    },
  },
}
