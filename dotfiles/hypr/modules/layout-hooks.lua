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
        local w = hl.get_config("scrolling.column_width")
        hl.dispatch(hl.dsp.layout("colresize " .. tostring(w)))
        return
    end

    -- Multiple windows: move to leftmost column (n left-moves is always enough),
    -- then sweep right resizing each column.
    -- On window.open the new window is focused and is the rightmost column,
    -- so n left-moves reaches column 1. Final position is rightmost = new window.
    local steps = {}
    for _ = 1, n do
        steps[#steps + 1] = function() hl.dispatch(hl.dsp.focus({ direction = "left" })) end
    end
    for _ = 1, n do
        steps[#steps + 1] = function() hl.dispatch(hl.dsp.layout("colresize 0.50")) end
        steps[#steps + 1] = function() hl.dispatch(hl.dsp.focus({ direction = "right" })) end
    end

    -- The viewport's "bring focused column into view" fit calculation runs on
    -- each focus change, but the last real transition above happens right
    -- after resizing the second-to-last column — while the final column is
    -- still at its old, wider size. So the on-screen scroll position gets
    -- fit against stale sizes. One more real left/right hop after every
    -- column is at its final width forces a fresh fit against final sizes.
    steps[#steps + 1] = function() hl.dispatch(hl.dsp.focus({ direction = "left" })) end
    steps[#steps + 1] = function() hl.dispatch(hl.dsp.focus({ direction = "right" })) end

    -- Firing every dispatch in one synchronous Lua call causes Hyprland to
    -- coalesce them — only the last dispatch of each type actually applies,
    -- so every column except the last one visited keeps its stale width.
    -- Running one step per event-loop tick (via chained oneshot timers)
    -- avoids the coalescing and lets each resize actually land.
    local function run_step(i)
        if i > #steps then return end
        steps[i]()
        hl.timer(function() run_step(i + 1) end, { timeout = 1, type = "oneshot" })
    end
    run_step(1)

    -- After the sweep, focus is at the new (rightmost) column — stay there.
end

-- Both window.open and window.destroy fire mid-processing, before Hyprland's
-- focus/layout state has settled. Dispatching the focus+colresize sweep
-- synchronously from inside the handler only reliably applies to the last
-- window touched (the new/focused one) — earlier windows in the sweep get
-- silently dropped. Deferring to the next event-loop tick via hl.timer lets
-- the handler return and the compositor settle before we dispatch anything.
hl.on("window.open",      function() hl.timer(_apply_col_width, { timeout = 1, type = "oneshot" }) end)
hl.on("window.destroy",   function() hl.timer(_apply_col_width, { timeout = 1, type = "oneshot" }) end)
hl.on("workspace.active", function() _apply_col_width() end)
