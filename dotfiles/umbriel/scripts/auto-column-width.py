#!/usr/bin/env python3
# auto-column-width.py — scrolling layout only: 1 tiled window -> 75%,
# 2+ tiled windows -> 50% each. Umbriel has no native "resize on column
# count change" option (confirmed against docs/user/layout.md); ported
# from dotfiles/hypr/modules/layout-hooks.lua, which solved the same gap
# in Hyprland the same way.
#
# window-set-width only targets the *focused* column (no resize-by-id
# action exists), so multi-column enforcement sweeps focus across every
# column, confirming by window ID which column is actually focused before
# resizing it — a focus command returns once the client sends it, not once
# the compositor has applied it, so resizing right after a focus change can
# otherwise land on the wrong column.
#
# Subscribes to both "windows" and "workspaces" events — window count
# alone isn't enough, since switching to a different workspace with no
# window-count change (e.g. workspace 1 has 1 window, workspace 2 has 2)
# needs re-enforcement too, same reason the old Hyprland version hooked
# "workspace.active" as well as window open/close. A window's own "active"
# field mirrors whether its workspace is the current one — no separate
# active-workspace query needed. Umbriel also tracks "focused" per
# workspace, not globally (multiple windows across different workspaces
# can show focused:true at once), so the active workspace is identified
# via "active", not "focused". Our own resize actions re-trigger the
# "windows" subscription — the (workspace, tiled count) guard is what
# stops that from looping.

import json
import subprocess
import time

SINGLE_WIDTH = 0.75
MULTI_WIDTH = 0.50

POLL_INTERVAL = 0.01
POLL_TIMEOUT = 0.3


def run(action):
    subprocess.run(["umbriel", "msg", action], check=False)


def get_windows():
    result = subprocess.run(
        ["umbriel", "windows", "--json"], capture_output=True, text=True, check=False
    )
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def focused_id(windows):
    # "active" pinpoints the one window with real input focus right now.
    # "focused" is per-workspace memory instead — multiple windows across
    # different, currently-inactive workspaces can each show focused:true
    # simultaneously, so it's not a reliable single-focus signal on its own.
    fw = next((w for w in windows if w.get("active")), None)
    return fw["id"] if fw else None


def wait_focused(expected_id):
    deadline = time.monotonic() + POLL_TIMEOUT
    while time.monotonic() < deadline:
        windows = get_windows()
        if windows is not None and focused_id(windows) == expected_id:
            return
        time.sleep(POLL_INTERVAL)


def active_workspace(windows):
    w = next((w for w in windows if w.get("active")), None)
    return w["workspace"] if w else None


def compute_state(windows):
    workspace = active_workspace(windows)
    if workspace is None:
        return None
    tiled = [w for w in windows if w["workspace"] == workspace and not w["floating"]]
    return (workspace, len(tiled))


def enforce(windows, workspace, count):
    if count == 0:
        return
    if count == 1:
        run(f"window-set-width:{SINGLE_WIDTH}")
        return
    tiled = [w for w in windows if w["workspace"] == workspace and not w["floating"]]
    ids = [w["id"] for w in sorted(tiled, key=lambda w: w["x"])]
    run("column-focus-first")
    wait_focused(ids[0])
    for i, wid in enumerate(ids):
        run(f"window-set-width:{MULTI_WIDTH}")
        if i < len(ids) - 1:
            run("window-focus-right")
            wait_focused(ids[i + 1])


def main():
    proc = subprocess.Popen(
        ["umbriel", "subscribe", "windows,workspaces"],
        stdout=subprocess.PIPE,
        text=True,
    )
    last_windows = get_windows() or []
    last_state = None
    for line in proc.stdout:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("event") == "windows":
            last_windows = event.get("data") or []
        # "workspaces" events carry workspace metadata, not windows — just
        # re-fetch to get "active" reflected onto the window list, cheaper
        # than cross-referencing the two event shapes.
        elif event.get("event") == "workspaces":
            last_windows = get_windows() or last_windows
        else:
            continue
        state = compute_state(last_windows)
        if state is None or state == last_state:
            continue
        last_state = state
        enforce(last_windows, state[0], state[1])


if __name__ == "__main__":
    main()
