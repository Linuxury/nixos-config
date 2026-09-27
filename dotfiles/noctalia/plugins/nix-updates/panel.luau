--!nonstrict
-- nix-updates panel: lists pending version changes, opens the plugin settings,
-- requests a check from the service, and runs the configured update in a
-- terminal followed by a re-check so the count resets.

local STATE_KEY = "nix_updates"
local REQUEST_KEY = "nix_updates_request"

local tr = noctalia.tr
local cfg = noctalia.getConfig

local function q(s)
  return "'" .. (string.gsub(s, "'", "'\\''")) .. "'"
end

local function checkNow()
  noctalia.state.set(REQUEST_KEY, (noctalia.state.get(REQUEST_KEY) or 0) + 1)
end

local function updateNow()
  local dir = noctalia.expandPath(cfg("flake_dir"))
  local host = cfg("host")
  local custom = cfg("custom_command")

  local cmd
  if cfg("update_method") == "custom" and custom ~= "" then
    cmd = custom
  else
    -- Safe default for any flake user: update inputs, then a plain switch.
    -- Needs sudo for the lock too when the flake lives somewhere root-owned (/etc/nixos).
    local target = host ~= "" and ("#" .. host) or ""
    cmd = `cd {q(dir)} && if [ -w flake.lock ]; then nix flake update; else sudo nix flake update; fi`
      .. ` && sudo nixos-rebuild switch --flake {q("." .. target)}`
  end

  local recheck = `sh {q(noctalia.pluginDir() .. "/check.sh")} {q(dir)} {q(host)} {q(noctalia.pluginDataDir() .. "/result")}`
  local full = `{cmd}; printf '\n%s\n' 'Re-checking for updates...'; {recheck}; printf '%s' 'Done. Press Enter to close.'; read _`

  local term = cfg("terminal")
  if term ~= "" then
    noctalia.runAsync(term .. " sh -c " .. q(full))
  else
    noctalia.runInTerminal(full)
  end
  panel.close()
end

local function statusText(s)
  if s == nil or s.checkedAt == nil then
    return s and s.phase == "checking" and tr("checking") or tr("never_checked")
  end
  local text = tr("last_check", { time = os.date("%b %d %H:%M", s.checkedAt) })
  if s.phase == "checking" then text ..= " · " .. tr("checking") end
  return text
end

local function body(s)
  local items = {}
  if s and s.phase == "error" then
    table.insert(items, ui.label({ text = tr("check_failed"), fontWeight = "bold", color = "error" }))
    table.insert(items, ui.label({ text = s.error or "", color = "on_surface_variant", maxLines = 6 }))
  end
  if s == nil or #s.rows == 0 then
    if not (s and s.phase == "error") then
      table.insert(items, ui.label({ text = tr("up_to_date"), color = "on_surface_variant" }))
    end
    return items
  end
  for _, r in s.rows do
    table.insert(items, ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = r.name, color = "on_surface", flexGrow = 1 }),
      ui.label({ text = r.old, color = "on_surface_variant" }),
      ui.glyph({ name = "arrow-right", size = 14, color = "on_surface_variant" }),
      ui.label({ text = r.new, color = "primary", fontWeight = "medium" }),
    }))
  end
  return items
end

local function render()
  local s = noctalia.state.get(STATE_KEY)
  local count = s and #s.rows or 0
  local title = count > 0 and `{tr("title")} · {count}` or tr("title")

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.glyph({ name = "package", size = 20, color = "primary" }),
      ui.label({ text = title, fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
      ui.button({ glyph = "settings", variant = "ghost", tooltip = tr("open_settings"), onClick = function() noctalia.openSettings() end }),
      ui.button({ glyph = "close", variant = "ghost", tooltip = tr("close"), onClick = function() panel.close() end }),
    }),
    ui.scroll({ flexGrow = 1, gap = 8, align = "stretch" }, body(s)),
    ui.separator({}),
    ui.label({ text = statusText(s), color = "on_surface_variant" }),
    ui.row({ gap = 8, justify = "end" }, {
      ui.button({ glyph = "refresh", text = tr("check_now"), enabled = not (s and s.phase == "checking"), onClick = checkNow }),
      ui.button({ glyph = "download", text = tr("update_now"), variant = "primary", onClick = updateNow }),
    }),
  }))
end

noctalia.state.watch(STATE_KEY, render)

function onOpen()
  render()
end

render()
