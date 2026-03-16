-- ============================================================
-- Autocompletion — nvim-cmp + LuaSnip + lspkind
-- ============================================================

local cmp     = require("cmp")
local luasnip = require("luasnip")
local lspkind = require("lspkind")

-- Load VSCode-style snippets (friendly-snippets)
require("luasnip.loaders.from_vscode").lazy_load()

luasnip.config.setup({
  history                 = true,
  updateevents            = "TextChanged,TextChangedI",
  enable_autosnippets     = true,
  region_check_events     = "CursorMoved",
  delete_check_events     = "TextChanged",
})

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },

  window = {
    completion    = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },

  formatting = {
    fields   = { "kind", "abbr", "menu" },
    format   = lspkind.cmp_format({
      mode         = "symbol_text",
      maxwidth     = 50,
      ellipsis_char = "...",
      symbol_map   = {
        Text          = "󰉿",
        Method        = "m",
        Function      = "󰊕",
        Constructor   = "",
        Field         = "",
        Variable      = "󰆧",
        Class         = "󰌗",
        Interface     = "",
        Module        = "",
        Property      = "",
        Unit          = "",
        Value         = "󰎠",
        Enum          = "",
        Keyword       = "󰌋",
        Snippet       = "",
        Color         = "󰏘",
        File          = "󰈙",
        Reference     = "",
        Folder        = "󰉋",
        EnumMember    = "",
        Constant      = "󰇽",
        Struct        = "",
        Event         = "",
        Operator      = "󰆕",
        TypeParameter = "󰊄",
      },
    }),
  },

  mapping = cmp.mapping.preset.insert({
    ["<C-k>"]     = cmp.mapping.select_prev_item(),
    ["<C-j>"]     = cmp.mapping.select_next_item(),
    ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
    ["<C-f>"]     = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"]     = cmp.mapping.abort(),
    ["<CR>"]      = cmp.mapping.confirm({ select = false }),  -- only confirm if explicitly selected
    -- Tab: cycle through completion items or expand/jump snippet
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expandable() then
        luasnip.expand()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),

  sources = cmp.config.sources({
    { name = "nvim_lsp", priority = 1000 },
    { name = "luasnip",  priority = 750  },
    { name = "buffer",   priority = 500  },
    { name = "path",     priority = 250  },
  }),

  -- Don't complete in comments
  enabled = function()
    local context = require("cmp.config.context")
    if vim.api.nvim_get_mode().mode == "c" then
      return true
    else
      return not context.in_treesitter_capture("comment")
        and not context.in_syntax_group("Comment")
    end
  end,

  experimental = {
    ghost_text = true,   -- inline preview of first completion
  },
})

-- Cmdline completion for "/"
cmp.setup.cmdline("/", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = { { name = "buffer" } },
})

-- Cmdline completion for ":"
cmp.setup.cmdline(":", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources(
    { { name = "path" } },
    { { name = "cmdline", option = { ignore_cmds = { "Man", "!" } } } }
  ),
})

-- ── Autopairs integration ─────────────────────────────────
local cmp_autopairs = require("nvim-autopairs.completion.cmp")
cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
