-- ===========================================================================
-- modules/layout-hooks.lua — Dynamic layout behaviors
--
-- Auto column width — scrolling layout only:
--   1 tiled window  → 67% (centered feel with margin)
--   2+ tiled windows → 50% (half-and-half fills the screen exactly)
--
-- Uses only native Lua dispatchers (hl.dispatch / hl.dsp.*).
-- hyprctl dispatch is broken in Hyprland 0.55 Lua IPC mode — all dispatches
-- are wrapped as "return hl.dispatch(arg)", making space-separated args
-- (e.g. "layoutmsg colresize 0.50") invalid Lua syntax.
--
-- Focus cycling uses direction-based movefocus (left/right) instead of
-- address-based focuswindow, since hl.dsp.focus({ direction }) is native.
-- ===========================================================================

local function _apply_col_width()
    local ws = hl.get_active_workspace()
    if not ws then return end

    -- Only run in scrolling layout
    local layout = hl.get_config("general.layout")
    if layout ~= "scrolling" then return end

    -- Count non-floating tiled windows on this workspace
    local wins = hl.get_workspace_windows(ws)
    local n = 0
    for _, w in ipairs(wins) do
        if not w.floating then n = n + 1 end
    end

    if n == 0 then return end

    -- Single window: resize current column and done.
    if n == 1 then
        hl.dispatch(hl.dsp.layout("colresize 0.67"))
        return
    end

    -- Multiple windows: move to leftmost column (n left-moves is always enough),
    -- then sweep right resizing each column.
    -- On window.open the new window is focused and is the rightmost column,
    -- so n left-moves reaches column 1. Final position is rightmost = new window.
    for _ = 1, n do
        hl.dispatch(hl.dsp.focus({ direction = "left" }))
    end
    for _ = 1, n do
        hl.dispatch(hl.dsp.layout("colresize 0.50"))
        hl.dispatch(hl.dsp.focus({ direction = "right" }))
    end

    -- After the sweep, focus is at the new (rightmost) column — stay there.
end

hl.on("window.open",      function() _apply_col_width() end)
hl.on("window.destroy",   function() _apply_col_width() end)
hl.on("workspace.active", function() _apply_col_width() end)
