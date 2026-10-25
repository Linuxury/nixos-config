--!nonstrict
-- nix-updates bar widget: one box and one number. Open box + total pending
-- (packages + flake inputs + Flatpaks) when there are updates; closed box when
-- there are none, shown only with always_show on. The per-kind split lives in
-- the tooltip and the panel. Pure renderer over the service's "nix_updates"
-- state. Material Design boxes as text: tabler (setGlyph) has no open box.

local PANEL_ID = "linuxury/nix-updates:panel"
local OPEN, CLOSED = "󰏖", "󰏗"

local function render(s)
  local n = { nix = 0, input = 0, flatpak = 0 }
  for _, r in (s and s.rows or {}) do
    n[r.kind] = (n[r.kind] or 0) + 1
  end
  local total = n.nix + n.input + n.flatpak
  local box = ui.label({ text = total > 0 and OPEN or CLOSED, fontSize = 17 })
  barWidget.render(total > 0
    and (barWidget.isVertical() and ui.column or ui.row)({ gap = 4, align = "center" }, { box, ui.label({ text = tostring(total) }) })
    or box)
  barWidget.setTooltip(total > 0
    and noctalia.tr("count_split", { nix = n.nix, inputs = n.input, flatpak = n.flatpak })
    or noctalia.tr("up_to_date"))
  barWidget.setVisible(total > 0 or noctalia.getConfig("always_show") == true)
end

noctalia.state.watch("nix_updates", render)
render(noctalia.state.get("nix_updates"))

function onConfigChanged()
  render(noctalia.state.get("nix_updates"))
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end
