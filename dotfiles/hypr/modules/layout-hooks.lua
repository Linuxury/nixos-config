-- ===========================================================================
-- modules/layout-hooks.lua — Dynamic layout behaviors
--
-- Auto column width — scrolling layout only:
--   1 tiled window  → 67% (centered feel with margin)
--   2+ tiled windows → 50% (half-and-half fills the screen exactly)
--
-- Fires on: window open, window destroy, workspace switch.
-- Skipped silently when the active layout is not scrolling.
-- ===========================================================================

-- ── Auto column width ────────────────────────────────────────────────────────
local _COL_SINGLE = "0.67"   -- 67%: one column with breathing room
local _COL_MULTI  = "0.50"   -- 50%: two columns fill the screen exactly

local function _apply_col_width()
    local ws = hl.get_active_workspace()
    if not ws then return end

    -- Only run in scrolling layout — other layouts don't have colresize
    local layout = hl.get_config("general.layout")
    if layout ~= "scrolling" then return end

    -- Collect non-floating tiled windows on this workspace
    local wins = hl.get_workspace_windows(ws)
    local tiled = {}
    for _, w in ipairs(wins) do
        if not w.floating then
            table.insert(tiled, w)
        end
    end

    if #tiled == 0 then return end

    local ratio = #tiled == 1 and _COL_SINGLE or _COL_MULTI

    -- colresize only affects the focused window's column, so we cycle focus
    -- through every tiled window, resize its column, then restore focus.
    -- All hyprctl calls are chained with && in one shell command to ensure
    -- they run sequentially (avoids focus-race from async exec_cmd calls).
    local active = hl.get_active_window()
    local restore_addr = active and active.address or nil

    local parts = {}
    for _, w in ipairs(tiled) do
        parts[#parts + 1] = "hyprctl dispatch focuswindow address:" .. w.address
        parts[#parts + 1] = "hyprctl dispatch layoutmsg 'colresize " .. ratio .. "'"
    end
    if restore_addr then
        parts[#parts + 1] = "hyprctl dispatch focuswindow address:" .. restore_addr
    end

    hl.exec_cmd(table.concat(parts, " && "))
end

-- window.open    — new window is already in the client list when this fires
-- window.destroy — window has been removed from the client list
-- workspace.active — re-apply when switching to a workspace with windows
hl.on("window.open",      function() _apply_col_width() end)
hl.on("window.destroy",   function() _apply_col_width() end)
hl.on("workspace.active", function() _apply_col_width() end)
