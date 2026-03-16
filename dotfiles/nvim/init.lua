-- ============================================================
-- Neovim Configuration Entry Point
-- ============================================================

-- Load Nix-injected paths (image paths, store paths).
-- Written by modules/home/neovim.nix → ~/.config/nvim/nix-paths.lua
-- Safe to skip if missing (e.g. first boot before HM activation).
local nix_paths = vim.fn.stdpath("config") .. "/nix-paths.lua"
if vim.fn.filereadable(nix_paths) == 1 then dofile(nix_paths) end

require("options")
require("keymaps")
require("autocmds")

-- Plugin configurations (load order matters)
require("plugins.colorscheme")   -- must be first
require("plugins.dashboard")     -- startup screen
require("plugins.neo-tree")      -- file explorer
require("plugins.lualine")       -- status bar
require("plugins.bufferline")    -- tab bar
require("plugins.noice")         -- UI overhaul (cmdline, messages)
require("plugins.which-key")     -- keybinding helper
require("plugins.treesitter")    -- syntax highlighting
require("plugins.lsp")           -- language server protocol
require("plugins.cmp")           -- autocompletion
require("plugins.telescope")     -- fuzzy finder
require("plugins.gitsigns")      -- git integration (gutter)
require("plugins.diffview")      -- git diff/history viewer
require("plugins.terminal")      -- claude-code + opencode
require("plugins.editor")        -- editing helpers
require("plugins.formatting")    -- format on save + linting
