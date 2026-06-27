-- ===========================================================================
-- modules/input.lua — Keyboard, touchpad, and mouse settings
-- ===========================================================================

hl.config({
    cursor = {
        warp_on_change_workspace = false,   -- Don't jump cursor when switching workspaces (was jumping when switching to Steam WS)
    },
})

hl.config({
    input = {
        kb_layout          = "us",
        kb_options         = "caps:escape",   -- Caps Lock → Escape (very useful in Neovim)
        numlock_by_default = true,

        -- Mouse — no acceleration, raw input feels more precise
        follow_mouse  = 1,
        sensitivity   = 0,
        accel_profile = "flat",

        touchpad = {
            natural_scroll       = true,    -- Scroll direction like macOS
            tap_to_click         = true,    -- Tap = left click
            tap_and_drag         = true,    -- Tap + hold = drag
            drag_lock            = false,
            disable_while_typing = true,
            scroll_factor        = 0.8,     -- Slightly slower scroll speed
        },
    },
})

-- Three-finger horizontal swipe between workspaces
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
