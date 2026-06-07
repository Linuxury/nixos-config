-- ===========================================================================
-- modules/layout-hooks.lua — Dynamic layout behaviors
--
-- Auto column width — scrolling layout only:
--   1 tiled window  → 67% (centered feel with margin)
--   2+ tiled windows → 50% (half-and-half fills the screen exactly)
--
-- Delegates to col-width-apply.sh which:
--   - Sleeps 0.1s to let Hyprland settle after open/close events
--   - Counts non-floating tiled windows via hyprctl + jq
--   - Cycles focus through all columns and resizes each
--   - Restores the original focused window
--
-- Fires on: window open, window destroy, workspace switch.
-- ===========================================================================

local home = os.getenv("HOME")
local _col_script = home .. "/.config/hypr/scripts/col-width-apply.sh"

local function _apply_col_width()
    hl.exec_cmd(_col_script)
end

hl.on("window.open",      function() _apply_col_width() end)
hl.on("window.destroy",   function() _apply_col_width() end)
hl.on("workspace.active", function() _apply_col_width() end)
