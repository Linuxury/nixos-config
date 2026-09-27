--!nonstrict
-- nix-updates bar widget: package glyph + pending count, hidden when there is
-- nothing to update. Pure renderer over the service's "nix_updates" state.

local PANEL_ID = "linuxury/nix-updates:panel"

local function render(s)
  local count = s and #s.rows or 0
  barWidget.setGlyph("package")
  barWidget.setText(tostring(count))
  barWidget.setTooltip(noctalia.tr("count", { count = count }))
  barWidget.setVisible(count > 0)
end

noctalia.state.watch("nix_updates", render)
render(noctalia.state.get("nix_updates"))

function onClick()
  noctalia.togglePanel(PANEL_ID)
end
