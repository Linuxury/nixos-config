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
# window-count change needs re-enforcement too, same reason the old
# Hyprland version hooked "workspace.active" as well as window open/close.
# A window's own "active" field mirrors whether its workspace is the
# current one. Umbriel tracks "focused" per workspace, not globally
# (multiple windows across different workspaces can show focused:true at
# once), so the active workspace/window is identified via "active".
#
# Each enforce() sweep costs several IPC round trips plus confirmation
# polling — opening windows faster than that (a few in quick succession)
# used to make this script fall behind and keep enforcing already-stale
# window counts, producing visible thrashing as it chased outdated state.
# Fixed by always draining to the newest buffered event before acting,
# rather than processing every event strictly in arrival order.

import json
import subprocess
import sys
import time
import select

SINGLE_WIDTH = 0.75
MULTI_WIDTH = 0.50

POLL_INTERVAL = 0.01
POLL_TIMEOUT = 0.3

DEBUG = True


def log(*args):
    if DEBUG:
        print(*args, file=sys.stderr, flush=True)


def run(action):
    log("  run:", action)
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


def wait_focus_change(prev_id):
    # Confirms a focus-changing action actually landed by waiting for the
    # focused id to differ from what it was before the action — not by
    # predicting which id comes next. An earlier version pre-sorted
    # columns by x-position and waited for that specific predicted id,
    # but a freshly-opened window can shift existing columns' x
    # coordinates before the sweep runs, making the prediction wrong
    # (confirmed live: the sweep's own log showed a window sorted first
    # that was actually at a higher x than the other one). Reacting to
    # "did focus actually move" sidesteps needing to know the real order
    # in advance.
    deadline = time.monotonic() + POLL_TIMEOUT
    while time.monotonic() < deadline:
        windows = get_windows()
        if windows is not None and focused_id(windows) != prev_id:
            return True
        time.sleep(POLL_INTERVAL)
    log("  wait_focus_change timed out, still on", prev_id)
    return False


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
    log(f"enforce: workspace={workspace} count={count}")
    if count == 0:
        return
    if count == 1:
        run(f"window-set-width:{SINGLE_WIDTH}")
        return
    # "column-focus-first" may be a no-op if the already-focused column
    # happens to already be first — can't wait for a focus change that
    # might not happen, so just give it a brief moment instead.
    run("column-focus-first")
    time.sleep(POLL_INTERVAL * 2)
    for i in range(count):
        run(f"window-set-width:{MULTI_WIDTH}")
        if i < count - 1:
            cur = focused_id(get_windows() or [])
            run("window-focus-right")
            wait_focus_change(cur)


def read_latest_event(proc):
    """Block until at least one line is available, then drain any lines
    that arrived while we were busy and return only the newest — avoids
    working through a backlog of already-stale window-count snapshots."""
    line = proc.stdout.readline()
    if not line:
        return None
    drained = 0
    while True:
        ready, _, _ = select.select([proc.stdout], [], [], 0)
        if not ready:
            break
        nxt = proc.stdout.readline()
        if not nxt:
            break
        line = nxt
        drained += 1
    if drained:
        log(f"  drained {drained} stale event(s)")
    return line


def main():
    proc = subprocess.Popen(
        ["umbriel", "subscribe", "windows,workspaces"],
        stdout=subprocess.PIPE,
        text=True,
    )
    last_windows = get_windows() or []
    last_state = None
    while True:
        line = read_latest_event(proc)
        if line is None:
            break
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("event") == "windows":
            last_windows = event.get("data") or []
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
