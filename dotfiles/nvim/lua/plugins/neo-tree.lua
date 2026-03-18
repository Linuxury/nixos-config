vim.g.loaded_netrw       = 1
vim.g.loaded_netrwPlugin = 1

-- Track layout mode so resurrection only fires when layout is active
vim.g.layout_active = false

-- Lock neo-tree window: fix width + neutralize q
vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree",
  callback = function(ev)
    vim.wo.winfixwidth = true
    vim.keymap.set("n", "q", function()
      vim.notify("Use <leader>e to toggle the explorer", vim.log.levels.INFO)
    end, { buffer = ev.buf, desc = "Panel locked" })
  end,
})

-- Resurrect neo-tree if closed while layout is active
vim.api.nvim_create_autocmd("WinClosed", {
  callback = function(ev)
    local win = tonumber(ev.match)
    if not (win and vim.g.layout_active) then return end
    local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
    if ok and vim.bo[buf].filetype == "neo-tree" then
      vim.schedule(function() vim.cmd("Neotree show") end)
    end
  end,
})

-- Auto-open Claude Code the first time the explorer opens
vim.api.nvim_create_autocmd("FileType", {
  pattern  = "neo-tree",
  once     = true,
  callback = function()
    vim.schedule(function()
      vim.cmd("ClaudeCode")
      vim.g.layout_active = true
    end)
  end,
})

-- Auto-preview: show highlighted file in center column as cursor moves
local _preview_timer = nil

local function neo_preview()
  if vim.bo.filetype ~= "neo-tree" then return end

  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if not ok then return end

  local state = manager.get_state("filesystem")
  if not (state and state.tree) then return end

  local node = state.tree:get_node()
  -- Only preview actual files, not directories
  if not (node and node.type == "file") then return end
  if vim.fn.filereadable(node.path) ~= 1 then return end

  local neo_win = vim.api.nvim_get_current_win()

  -- Find center window: not neo-tree, not terminal, not nofile (dashboard/scratch)
  local center_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= neo_win then
      local buf = vim.api.nvim_win_get_buf(win)
      local bt  = vim.bo[buf].buftype
      local ft  = vim.bo[buf].filetype
      if ft ~= "neo-tree" and bt ~= "terminal" and bt ~= "nofile" and bt ~= "prompt" then
        center_win = win
        break
      end
    end
  end

  -- No regular window found — open a vertical split next to neo-tree
  if not center_win then
    vim.cmd("vsplit")
    center_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(neo_win)  -- return focus to neo-tree
  end

  local pbuf = vim.fn.bufadd(node.path)
  vim.fn.bufload(pbuf)
  pcall(vim.api.nvim_win_set_buf, center_win, pbuf)
end

vim.api.nvim_create_autocmd("CursorMoved", {
  callback = function()
    if vim.bo.filetype ~= "neo-tree" then return end
    if _preview_timer then
      _preview_timer:stop()
      _preview_timer:close()
      _preview_timer = nil
    end
    _preview_timer = vim.uv.new_timer()
    _preview_timer:start(150, 0, vim.schedule_wrap(neo_preview))
  end,
})

require("neo-tree").setup({
  close_if_last_window = false,
  window = {
    width    = 30,
    position = "left",
    mappings = {
      ["q"]     = function() vim.notify("Use <leader>e to toggle the explorer", vim.log.levels.INFO) end,
      ["<C-h>"] = function() vim.cmd("wincmd h") end,
      ["<C-j>"] = function() vim.cmd("wincmd j") end,
      ["<C-k>"] = function() vim.cmd("wincmd k") end,
      ["<C-l>"] = function() vim.cmd("wincmd l") end,
    },
  },
  filesystem = {
    follow_current_file  = { enabled = true },
    hide_dotfiles        = true,
    hide_gitignored      = true,
  },
  default_component_configs = {
    git_status = {
      symbols = { added = " ", modified = " ", deleted = " ", renamed = "➜", untracked = "★" },
    },
  },
})
