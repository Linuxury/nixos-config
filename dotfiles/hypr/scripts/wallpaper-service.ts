// =============================================================================
// wallpaper-service.ts — AGS wallpaper rotation + matugen daemon
//
// Uses native astal-hyprland for fullscreen detection instead of parsing JSON.
// Uses only gentle transitions — grow/outer/center caused GPU spikes that
// crashed apps (Steam, games, Firefox).
//
// Run with:  ags run ~/.config/hypr/scripts/wallpaper-service.ts
// Keybinds still call set-wallpaper.sh directly (SUPER+W / SUPER+SHIFT+W).
// Both share the LAST_FILE so state stays consistent.
// =============================================================================

import App from "astal/gtk4/app"
import Hyprland from "gi://AstalHyprland"
import GLib from "gi://GLib"
import Gio from "gi://Gio"

// ─── Constants ────────────────────────────────────────────────────────────────

const HOME         = GLib.get_home_dir()!
const WALLPAPER_DIR = `${HOME}/Pictures/Wallpapers`
const LAST_FILE    = `${HOME}/.local/share/last-matugen-wallpaper`
const LOG_FILE     = `${HOME}/.local/share/wallpaper-service.log`
const GREETER_FILE = "/var/lib/wallpapers/current.jpg"

// Gentle transitions only.
// Removed: grow, outer, center, any, random
// — those create full-screen circular GPU animations that can crash apps.
const TRANSITIONS = ["fade", "wipe", "left", "right", "top", "bottom"] as const

// ─── Logging ──────────────────────────────────────────────────────────────────

function log(msg: string): void {
    const now = GLib.DateTime.new_now_local()?.format("%H:%M:%S") ?? "??:??:??"
    const line = `[${now}] ${msg}\n`
    try {
        const file   = Gio.File.new_for_path(LOG_FILE)
        const stream = file.append_to(Gio.FileCreateFlags.NONE, null)
        stream.write_all(new TextEncoder().encode(line), null)
        stream.close(null)
    } catch { /* ignore log failures */ }
    print(line.trimEnd())
}

// ─── Subprocess helper ────────────────────────────────────────────────────────

interface RunResult { ok: boolean; stdout: string; stderr: string }

function run(argv: string[]): RunResult {
    try {
        const [ok, outBytes, errBytes] = GLib.spawn_sync(
            null,                       // working dir
            argv,                       // command + args
            null,                       // inherit env
            GLib.SpawnFlags.SEARCH_PATH,
            null,                       // child_setup
        )
        const decode = (b: Uint8Array | null) =>
            b ? new TextDecoder().decode(b).trim() : ""
        return { ok: !!ok, stdout: decode(outBytes), stderr: decode(errBytes) }
    } catch (e) {
        return { ok: false, stdout: "", stderr: String(e) }
    }
}

// ─── Fullscreen detection — native Hyprland IPC ───────────────────────────────
// Hyprland reports fullscreen as an integer: 0=none, 1=fullscreen, 2=fake.
// Using astal-hyprland avoids spawning a subprocess and parsing JSON.

function hasFullscreenWindow(): boolean {
    try {
        return Hyprland.get_default()
            .get_clients()
            .some((c: { fullscreen: number }) => c.fullscreen > 0)
    } catch {
        return false  // if IPC isn't available, don't block rotation
    }
}

// ─── Wallpaper utilities ──────────────────────────────────────────────────────

function listWallpapers(): string[] {
    const result: string[] = []
    try {
        const dir = Gio.File.new_for_path(WALLPAPER_DIR)
        const en  = dir.enumerate_children(
            "standard::name", Gio.FileQueryInfoFlags.NONE, null
        )
        let info: Gio.FileInfo | null
        while ((info = en.next_file(null)) !== null) {
            const name = info.get_name()!
            if (/\.(jpe?g|png|webp)$/i.test(name))
                result.push(`${WALLPAPER_DIR}/${name}`)
        }
    } catch (e) { log(`WARN list: ${e}`) }
    return result
}

function pickRandom<T>(arr: T[]): T | null {
    return arr.length ? arr[Math.floor(Math.random() * arr.length)] : null
}

function readText(path: string): string {
    try {
        const [, bytes] = GLib.file_get_contents(path)
        return new TextDecoder().decode(bytes).trim()
    } catch { return "" }
}

function inode(path: string): string {
    return run(["stat", "-c", "%d:%i", path]).stdout
}

// Compare by inode so symlink vs. real-path differences don't matter.
// ~/Pictures/Wallpapers is mkOutOfStoreSymlink → nixos-config/assets/Wallpapers/<dir>
function sameFile(a: string, b: string): boolean {
    if (!a || !b) return false
    const ia = inode(a), ib = inode(b)
    return !!ia && ia === ib
}

// Ask awww what wallpaper is currently displayed
function currentAwwwWallpaper(): string {
    const r = run(["awww", "query", "-j"])
    if (!r.ok || !r.stdout) return ""
    try {
        const d = JSON.parse(r.stdout) as Record<
            string,
            Array<{ displaying?: { image?: string } }>
        >
        return Object.values(d)[0]?.[0]?.displaying?.image ?? ""
    } catch { return "" }
}

// ─── Core: set wallpaper + run matugen ───────────────────────────────────────

function apply(wallpaper: string): void {
    const transition = pickRandom([...TRANSITIONS]) ?? "fade"

    // Set via awww
    const awww = run([
        "awww", "img", wallpaper,
        "--transition-type",     transition,
        "--transition-fps",      "60",
        "--transition-duration", "0.8",
    ])
    if (!awww.ok) log(`WARN awww: ${awww.stderr}`)

    // Extract dominant color via imagemagick
    const conv = run(["convert", wallpaper, "-resize", "1x1", "txt:-"])
    const hex  = conv.stdout.match(/#[0-9a-fA-F]{6}/)?.[0] ?? null
    if (!hex) { log(`WARN no color: ${wallpaper.split("/").at(-1)}`); return }

    log(`COLOR ${hex}`)

    // Write LAST before matugen so a failed matugen doesn't cause infinite retry
    try { GLib.file_set_contents(LAST_FILE, wallpaper) } catch { /* ignore */ }

    const mat = run(["matugen", "color", "hex", hex])
    if (!mat.ok) log(`WARN matugen: ${mat.stderr}`)

    // Sync to cosmic-greeter (can't read ~/Pictures/, so we use /var/lib/wallpapers/)
    run(["cp", "-f", wallpaper, GREETER_FILE])

    log(`DONE ${wallpaper.split("/").at(-1)}`)
}

// ─── Rotation logic ───────────────────────────────────────────────────────────

function rotate(force = false): void {
    if (!force && hasFullscreenWindow()) { log("SKIP fullscreen"); return }

    const last = readText(LAST_FILE)
    let   candidates = listWallpapers()

    // Always pick something different from the current wallpaper
    const fresh = candidates.filter(w => !sameFile(w, last))
    if (fresh.length) candidates = fresh  // if only one wallpaper exists, allow repeat

    const wallpaper = pickRandom(candidates)
    if (!wallpaper) { log("SKIP no wallpapers"); return }

    log(`SET ${wallpaper.split("/").at(-1)}`)
    apply(wallpaper)
}

// ─── Startup sync ─────────────────────────────────────────────────────────────
// awww restores its last wallpaper on daemon restart, but matugen may not have
// run yet (or colors may be stale from a different session). Compare inodes
// to detect divergence and resync without visually changing the wallpaper.

function syncOnStart(): void {
    const current = currentAwwwWallpaper()

    if (!current) {
        // awww has no wallpaper (first boot or cleared state) — pick one
        log("STARTUP: awww empty, picking random")
        const w = pickRandom(listWallpapers())
        if (w) apply(w)
        return
    }

    const last = readText(LAST_FILE)
    if (!last || !sameFile(current, last)) {
        log(`STARTUP SYNC: ${current.split("/").at(-1)}`)
        apply(current)   // resync matugen without visually changing wallpaper
    } else {
        log("STARTUP OK: in sync")
    }
}

// ─── Rotation timer ───────────────────────────────────────────────────────────
// Rotate at :00 and :30 of each hour (same schedule as the old bash daemon).

function secondsToNextSlot(): number {
    const now  = GLib.DateTime.new_now_local()!
    const m    = now.get_minute()
    const s    = now.get_second()
    const wait = m < 30 ? (30 - m) * 60 - s : (60 - m) * 60 - s
    return Math.max(wait, 5)  // at least 5 seconds
}

function scheduleNext(): void {
    const secs = secondsToNextSlot()
    log(`NEXT in ${Math.floor(secs / 60)}m ${secs % 60}s`)
    GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, secs, () => {
        rotate()
        scheduleNext()
        return GLib.SOURCE_REMOVE
    })
}

// ─── Entry point ─────────────────────────────────────────────────────────────

App.start({
    instanceName: "wallpaper-service",
    main() {
        // Prevent GTK from exiting when there are no windows
        App.hold()

        log("=== wallpaper-service started ===")
        syncOnStart()
        scheduleNext()
    },
})
