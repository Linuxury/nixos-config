#!/usr/bin/env python3
# auto-column-width.py — scrolling layout only: 1 tiled window -> 75%,
# 2+ tiled windows -> 50% each. Umbriel has no native "resize on column
# count change" option (confirmed against docs/user/layout.md); ported
# from dotfiles/hypr/modules/layout-hooks.lua, which solved the same gap
# in Hyprland the same way.
#
# window-set-width only targets the *focused* column (no resize-by-id
# action exists), so multi-column enforcement sweeps focus across every
# column. Subscribing to our own "windows" event stream means our own
# resize actions re-trigger this script — the (workspace, tiled count)
# guard below is what stops that from looping.

import json
import subprocess
import time

SINGLE_WIDTH = 0.75
MULTI_WIDTH = 0.50

# Each `umbriel msg` call returns once the client sends the message, not once
# the compositor has finished processing it — a resize sent right after a
# focus change can land before the focus change actually takes effect
# server-side. A short gap avoids that race (same class of problem
# dotfiles/hypr/modules/layout-hooks.lua worked around with deferred timers).
STEP_DELAY = 0.05


def msg(action):
    subprocess.run(["umbriel", "msg", action], check=False)
    time.sleep(STEP_DELAY)


def compute_state(windows):
    focused = next((w for w in windows if w.get("focused")), None)
    if focused is None:
        return None
    workspace = focused["workspace"]
    tiled = [w for w in windows if w["workspace"] == workspace and not w["floating"]]
    return (workspace, len(tiled))


def enforce(count):
    if count == 0:
        return
    if count == 1:
        msg(f"window-set-width:{SINGLE_WIDTH}")
        return
    msg("column-focus-first")
    for i in range(count):
        msg(f"window-set-width:{MULTI_WIDTH}")
        if i < count - 1:
            msg("window-focus-right")


def main():
    proc = subprocess.Popen(
        ["umbriel", "subscribe", "windows"], stdout=subprocess.PIPE, text=True
    )
    last_state = None
    for line in proc.stdout:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        windows = event.get("data")
        if windows is None:
            continue
        state = compute_state(windows)
        if state is None or state == last_state:
            continue
        last_state = state
        enforce(state[1])


if __name__ == "__main__":
    main()
