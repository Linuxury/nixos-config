#!/usr/bin/env python3
# auto-column-width.py — scrolling layout only: 1 tiled window -> 75%,
# 2+ tiled windows -> 50% each. Umbriel has no native "resize on column
# count change" option (confirmed against docs/user/layout.md); ported
# from dotfiles/hypr/modules/layout-hooks.lua, which solved the same gap
# in Hyprland the same way.
#
# window-set-width only targets the *focused* column (no resize-by-id
# action exists), so multi-column enforcement sweeps focus across every
# column, confirming each focus change actually landed (by geometry/id,
# not a fixed delay) before resizing.
#
# Real usage (opening/closing windows faster than a sweep completes)
# exposed a deeper problem than any single confirmation bug: a sweep
# built for an earlier window count can end up trying to focus-right
# onto a column that's already been closed by the time it gets there,
# timing out for a real reason (nothing to focus), not a bug in the
# check itself. Fixed by re-deriving the real (workspace, count) before
# every single action in the sweep, not just between whole sweeps, and
# aborting (Stale exception) the moment it no longer matches what the
# sweep started with. A first version checked "is there unread data in
# the subscribe pipe" instead — that fires on the sweep's *own* actions
# (every focus change and resize emits its own "windows" event through
# the same subscription), so it aborted on itself constantly and never
# completed a sweep at all. Count doesn't change from our own actions
# (only focus/width do), so comparing count is what actually
# distinguishes "something external happened" from an echo.

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


class Stale(Exception):
    """The real (workspace, count) has changed since this sweep started —
    abandon it, the main loop will start a fresh sweep from current state
    right after."""


def check_fresh(target):
    # Re-derives the actual current state and compares against what this
    # sweep was called for — not "is there unread data in the subscribe
    # pipe", which triggers on the sweep's *own* actions (every focus
    # change and resize emits its own "windows" event through the same
    # subscription), making that check fire constantly and never let a
    # sweep complete. Window *count* doesn't change from our own actions
    # (only focus/width do), so comparing count is a clean signal for
    # "something external actually happened".
    if compute_state(get_windows() or []) != target:
        raise Stale()


DISPATCH_DELAY = 0.05


def run(action):
    log("  run:", action)
    subprocess.run(["umbriel", "msg", action], check=False)
    # Testing whether Umbriel's own IPC/dispatch handling needs pacing
    # between consecutive `umbriel msg` calls — confirmation timeouts kept
    # happening even with count stable (no external change mid-sweep),
    # succeeding roughly 1 in 5 tries, which points at something on
    # Umbriel's side rather than a logic bug in this script.
    time.sleep(DISPATCH_DELAY)


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


def wait_focus_change(target, prev_id):
    deadline = time.monotonic() + POLL_TIMEOUT
    while time.monotonic() < deadline:
        check_fresh(target)
        windows = get_windows()
        if windows is not None and focused_id(windows) != prev_id:
            return
        time.sleep(POLL_INTERVAL)
    log("  wait_focus_change timed out, still on", prev_id)


def on_first_column(workspace):
    # Verifies by geometry (leftmost x among this workspace's tiled
    # windows) rather than assuming column-focus-first landed after a
    # fixed delay — a freshly-opened window usually grabs focus
    # automatically, so the sweep's first resize could silently land on
    # that new window instead of column 1 if this isn't actually
    # confirmed first.
    windows = get_windows()
    if not windows:
        return False
    tiled = [w for w in windows if w["workspace"] == workspace and not w["floating"]]
    if not tiled:
        return False
    min_x = min(w["x"] for w in tiled)
    active = next((w for w in windows if w.get("active")), None)
    return active is not None and active["x"] == min_x


def wait_first_column(target, workspace):
    deadline = time.monotonic() + POLL_TIMEOUT
    while time.monotonic() < deadline:
        check_fresh(target)
        if on_first_column(workspace):
            return
        time.sleep(POLL_INTERVAL)
    log("  wait_first_column timed out")


def active_workspace(windows):
    w = next((w for w in windows if w.get("active")), None)
    return w["workspace"] if w else None


def compute_state(windows):
    workspace = active_workspace(windows)
    if workspace is None:
        return None
    tiled = [w for w in windows if w["workspace"] == workspace and not w["floating"]]
    return (workspace, len(tiled))


def enforce(workspace, count):
    log(f"enforce: workspace={workspace} count={count}")
    if count == 0:
        return
    if count == 1:
        run(f"window-set-width:{SINGLE_WIDTH}")
        return
    target = (workspace, count)
    check_fresh(target)
    run("column-focus-first")
    wait_first_column(target, workspace)
    for i in range(count):
        check_fresh(target)
        run(f"window-set-width:{MULTI_WIDTH}")
        if i < count - 1:
            check_fresh(target)
            cur = focused_id(get_windows() or [])
            run("window-focus-right")
            wait_focus_change(target, cur)


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
        try:
            enforce(state[0], state[1])
        except Stale:
            log("  sweep abandoned — state changed mid-sweep")
            last_state = None


if __name__ == "__main__":
    main()
