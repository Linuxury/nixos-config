require("obsidian").setup({
  workspaces = {
    { name = "personal", path = "~/Obsidian" },
  },

  -- Daily notes
  daily_notes = {
    folder      = "Daily",
    date_format = "%Y-%m-%d",
  },

  -- Use telescope for search/picker
  picker = { name = "telescope" },

  -- nvim-cmp completion for [[links]]
  completion = {
    nvim_cmp = true,
    min_chars = 2,
  },

  -- Note ID = slugified title
  note_id_func = function(title)
    local s = title ~= nil and title or tostring(os.time())
    return s:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
  end,

  -- Open links with gf
  follow_url_func = function(url)
    vim.fn.jobstart({ "xdg-open", url })
  end,

  ui = {
    enable         = true,
    checkboxes     = {
      [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
      ["x"] = { char = "", hl_group = "ObsidianDone" },
      [">"] = { char = "", hl_group = "ObsidianRightArrow" },
      ["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },
    },
    bullets        = { char = "•", hl_group = "ObsidianBullet" },
    external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
    reference_text = { hl_group = "ObsidianRefText" },
    highlight_text = { hl_group = "ObsidianHighlightText" },
    tags           = { hl_group = "ObsidianTag" },
  },

  mappings = {
    ["<leader>of"] = { action = require("obsidian").actions.follow_link,    opts = { desc = "Follow link" } },
    ["<leader>ob"] = { action = require("obsidian").actions.smart_action,   opts = { desc = "Smart action" } },
  },
})

-- Keymaps
local map = function(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { noremap = true, silent = true, desc = desc })
end

map("<leader>on",  "<cmd>ObsidianNew<cr>",          "New note")
map("<leader>oo",  "<cmd>ObsidianOpen<cr>",          "Open in Obsidian app")
map("<leader>os",  "<cmd>ObsidianSearch<cr>",        "Search notes")
map("<leader>oq",  "<cmd>ObsidianQuickSwitch<cr>",   "Quick switch note")
map("<leader>od",  "<cmd>ObsidianToday<cr>",         "Today's daily note")
map("<leader>oy",  "<cmd>ObsidianYesterday<cr>",     "Yesterday's daily note")
map("<leader>ol",  "<cmd>ObsidianLinks<cr>",         "List links")
map("<leader>oB",  "<cmd>ObsidianBacklinks<cr>",     "Backlinks")
map("<leader>ot",  "<cmd>ObsidianTags<cr>",          "Search tags")
map("<leader>oT",  "<cmd>ObsidianTemplate<cr>",      "Insert template")
