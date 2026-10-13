--!nonstrict
-- nix-updates bar widget: package glyph + pending counts per kind ("❄ 2  󰏖 3",
-- zero counts left out), hidden when there is nothing to update. Pure renderer
-- over the service's "nix_updates" state.

local PANEL_ID = "linuxury/nix-updates:panel"

local function render(s)
  local nix, flatpak = 0, 0
  for _, r in (s and s.rows or {}) do
    if r.kind == "flatpak" then flatpak += 1 else nix += 1 end
  end
  local parts = {}
  if nix > 0 then table.insert(parts, `❄ {nix}`) end
  if flatpak > 0 then table.insert(parts, `󰏖 {flatpak}`) end
  barWidget.setGlyph("package")
  barWidget.setText(table.concat(parts, "  "))
  barWidget.setTooltip(noctalia.tr("count_split", { nix = nix, flatpak = flatpak }))
  barWidget.setVisible(nix + flatpak > 0)
end

noctalia.state.watch("nix_updates", render)
render(noctalia.state.get("nix_updates"))

function onClick()
  noctalia.togglePanel(PANEL_ID)
end
