# Theming

How the dynamic theming pipeline works — wallpaper rotation, matugen color generation, and desktop customization. The system automatically adapts terminal, editor, and app colors to match the current wallpaper without any manual steps.

---

## Contents

- [Overview](#overview)
- [Wallpapers](#wallpapers)
- [matugen](#matugen)
- [COSMIC Pipeline — wallpaper-color-sync](#cosmic-pipeline--wallpaper-color-sync)
- [Hyprland Pipeline — matugen service](#hyprland-pipeline--matugen-service)
- [COSMIC Configuration](#cosmic-configuration)
- [Cursor and Icons](#cursor-and-icons)
- [What NOT to Do](#what-not-to-do)

---

## Overview

There are two separate theming pipelines — one for COSMIC (babylinux and alex) and one for Hyprland (linuxury). Both follow the same pattern: when the wallpaper changes, the dominant color is extracted via ImageMagick, passed to matugen, and all configured templates are regenerated automatically.

### COSMIC pipeline

```
COSMIC wallpaper slideshow rotation
        ↓
wallpaper-color-sync (systemd path unit watches COSMIC config dir)
        ↓
Reads current wallpaper path from COSMIC's config
        ↓
Checks last-run cache — skips if wallpaper hasn't changed
        ↓
Extracts dominant color via ImageMagick: convert img -resize 1x1 info:
        ↓
matugen color hex "#<HEX>" generates a full Material You color palette
        ↓
Writes colors to template outputs:
  ~/.config/starship-colors.toml        (Starship prompt)
  ~/.config/gtk-4.0/colors.css          (GTK4 apps)
  ~/.config/matugen/themes/matugen_cosmic.theme.ron  (COSMIC appearance)
  ~/.config/kitty/colors.conf           (Kitty terminal)
  ~/.config/btop/themes/matugen.theme   (btop)
  ~/.config/zed/themes/matugen.json     (Zed editor)
  ~/.config/mango/config.conf           (MangoWC bar)
```

### Hyprland pipeline

```
Noctalia/Wayle shell changes wallpaper
        ↓
Writes current wallpaper path to ~/.local/share/current-wallpaper
        ↓
matugen (systemd path unit watches that file)
        ↓
Checks last-run cache — skips if wallpaper hasn't changed
        ↓
Extracts dominant color via ImageMagick
        ↓
matugen color hex "#<HEX>" generates a full Material You color palette
        ↓
Writes colors to template outputs:
  ~/.config/hypr/colors.lua             (Hyprland border/accent colors)
  ~/.config/kitty/colors.conf           (Kitty terminal)
  ~/.config/gtk-4.0/colors.css          (GTK4 apps)
  ~/.config/gtk-4.0/libadwaita-matugen.css  (libadwaita apps)
  ~/.config/rofi/window.rasi            (Rofi launcher)
  ~/.config/hypr/colors-hyprlock.conf   (Hyprlock screen lock)
        ↓
apply_borders: updates Hyprland border colors live via hyprctl keyword
        ↓
Syncs wallpaper to SDDM login screen (/var/lib/sddm-wallpaper/background.jpg)
```

---

## Wallpapers

### Source locations

All users symlink wallpapers from the nixos-config repo — no separate assets directory needed:

| User | Wallpaper source | Symlinked to |
|------|-----------------|--------------|
| linuxury | `~/nixos-config/assets/Wallpapers/<dir>/` | `~/Pictures/Wallpapers/` |
| babylinux | `~/nixos-config/assets/Wallpapers/<dir>/` | `~/Pictures/Wallpapers/` |
| alex | `~/nixos-config/assets/Wallpapers/<dir>/` | `~/Pictures/Wallpapers/` |

The `<dir>` is the `wallpaperDir` from `flake.nix`:

| Host | wallpaperDir |
|------|-------------|
| ThinkPad | `4k` |
| Ryzen5900x | `3440x1440` |
| Ryzen5800x, Asus-A15 | `4k` |
| Alex-Desktop, Alex-Laptop | `PikaOS` |

### Setting the wallpaper — COSMIC

Set wallpapers and configure the slideshow via **COSMIC Settings → Desktop → Wallpaper**. COSMIC handles the rotation interval and order.

> Do not edit COSMIC's wallpaper config files directly. COSMIC writes them in RON (Rusty Object Notation) format. Any manual edit — even a minor formatting change — can corrupt the file and cause `cosmic-session` to enter exponential backoff restart loops. Use the COSMIC Settings GUI only.

### Setting the wallpaper — Hyprland

Wallpapers are managed by the active shell (Noctalia or Wayle). Change the wallpaper through the shell's wallpaper picker or configuration — not by editing config files directly.

---

## matugen

**matugen** is a Material You color scheme generator. It takes a dominant color (extracted from the wallpaper via ImageMagick) and produces a full color palette, then writes that palette into template files.

Material You is the design language used in Android 12+ — the idea is that the whole system's color scheme derives from a single source image rather than a static theme choice.

### Templates

Templates are cloned from the community template repo at activation time:

```
~/.config/matugen/templates/   ← git clone of InioX/matugen-themes
```

Home Manager auto-clones this directory if it's missing (via `home.activation.matugenTemplates`). You don't need to clone it manually.

**matugen config:** `~/.config/matugen/config.toml` — written declaratively by Home Manager with `force = true` so it always reflects the current config.

### Seed files

One empty seed file is pre-created by Home Manager activation before matugen first runs:

- `~/.config/kitty/colors.conf`

This must exist before matugen runs — otherwise matugen errors trying to write to a nonexistent path. Home Manager creates it so the pipeline works from the first wallpaper change.

---

## COSMIC Pipeline — wallpaper-color-sync

Module: `modules/services/wallpaper-slideshow/default.nix`

Two systemd user units work together to trigger matugen when the wallpaper changes.

### wallpaper-color-sync.path

Watches `~/.config/cosmic/com.system76.CosmicBackground/v1/` for file changes. When COSMIC writes a wallpaper update to that directory, the path unit immediately triggers the service.

### wallpaper-color-sync.timer

Fires 30 seconds after session start, then every 10 minutes. This catches wallpaper rotations where COSMIC rotates through a directory source without writing a new config file (which wouldn't trigger the path unit).

### What the service does

1. Checks per-output config files (DP-3, HDMI-A-1, etc.) first, then falls back to the `all` file
2. Reads the current wallpaper path from COSMIC's config
3. Compares it to `~/.local/share/last-matugen-wallpaper` — if they match, skips (feedback loop prevention)
4. Extracts the dominant color using ImageMagick: `convert img -resize 1x1 -format "%[hex:u]" info:`
5. Runs `matugen color hex "#<HEX>"` — writes all template outputs
6. Saves the wallpaper path to `~/.local/share/last-matugen-wallpaper`

Service logs: `~/.local/share/wallpaper-slideshow.log`

### Checking the service

```bash
systemctl --user status wallpaper-color-sync     # check current status and last run time
journalctl --user -u wallpaper-color-sync -f     # follow live logs
```

### Forcing a color refresh

```bash
systemctl --user restart wallpaper-color-sync   # force a run immediately
```

If colors are stuck on an old wallpaper (the cache is preventing a re-run):

```bash
rm ~/.local/share/last-matugen-wallpaper        # clear the cache
systemctl --user restart wallpaper-color-sync   # run matugen unconditionally
```

---

## Hyprland Pipeline — matugen service

Module: `modules/compositors/hyprland/matugen/default.nix`

### matugen.path

Watches `~/.local/share/current-wallpaper` for changes. Each wallpaper shell (Noctalia, Wayle) writes this file when the wallpaper changes. This decouples matugen from any specific shell implementation.

### matugen.timer

Fires 10 seconds after session start. Gives the wallpaper shell time to initialize and set the first wallpaper before matugen queries it.

### What the service does

1. Reads `~/.local/share/current-wallpaper`
2. Compares it to `~/.local/share/last-matugen-processed` — if they match AND `colors.lua` exists, applies border colors and exits
3. Extracts the dominant color using ImageMagick
4. Runs `matugen color hex "#<HEX>"` — writes all template outputs
5. Applies Hyprland border colors live via `hyprctl keyword` (no full reload needed)
6. Syncs the wallpaper to `/var/lib/sddm-wallpaper/background.jpg` for the login screen
7. Saves the wallpaper path to `~/.local/share/last-matugen-processed`

Service logs: `~/.local/share/wallpaper-service.log`

### Checking the service

```bash
systemctl --user status matugen           # check current status
journalctl --user -u matugen -f           # follow live logs
```

### Forcing a color refresh

```bash
rm ~/.local/share/last-matugen-processed   # clear the deduplication stamp
systemctl --user restart matugen           # run matugen unconditionally
```

---

## COSMIC Configuration

COSMIC settings are written declaratively via `home.file` in `modules/desktops/cosmic/themes/default.nix`. These are plain text files placed at the appropriate paths under `~/.config/cosmic/`.

> These files are written at build/activation time. Do not edit them manually while COSMIC is running — COSMIC holds the files open and manual edits cause parse errors.

### Files sidebar favorites

Defined in the shared COSMIC themes module (`modules/desktops/cosmic/themes/default.nix`). All three users get the same favorites:

```ron
[
    Home,
    Documents,
    Downloads,
    Music,
    Pictures,
    Videos,
    Path("/mnt/Media-Server"),
    Path("/mnt/MinisForum"),
    Path("/mnt/Torrents"),
]
```

Only network shares appear in this file. Local drives show up automatically in COSMIC's **Devices** section and don't need explicit entries.

Mount path capitalization matters for display — the last path segment becomes the label shown in the sidebar:

```
/mnt/Media-Server    ✓ (displays as "Media-Server")
/mnt/media-server    ✗ (would display as "media-server")
```

### Adding a new share

Edit the favorites block in `modules/desktops/cosmic/themes/default.nix`, then rebuild:

```nix
home.file.".config/cosmic/com.system76.CosmicFiles/v1/favorites" = {
  force = true;
  text = ''
    [
        Home,
        Documents,
        Downloads,
        Music,
        Pictures,
        Videos,
        Path("/mnt/Media-Server"),
        Path("/mnt/MinisForum"),
        Path("/mnt/Torrents"),
        Path("/mnt/NewShare"),    # ← add here
    ]
  '';
};
```

Then rebuild: `nr`

---

## Cursor and Icons

Cursor and icon theme are defined in the shared GTK base module (`modules/themes/gtk/default.nix`), which is imported by every compositor and desktop theme module. All users and all desktops get the same cursor.

### Cursor

- **Theme:** BreezeX-Light
- **Source:** Custom Nix derivation fetching `BreezeX.tar.xz` from the `ful1e5/BreezeX_Cursor` GitHub releases (v2.0.1)
- **Applied via:** `home.pointerCursor` in `modules/themes/gtk/default.nix` — sets `XCURSOR_THEME`/`XCURSOR_SIZE` in the systemd user environment, creates `~/.icons/default/index.theme` for X11 fallback, and writes GTK cursor config
- **Size:** 24

### GTK theme

- **Theme:** adw-gtk3-dark (`pkgs.adw-gtk3`) — applied to GTK3 and GTK4 apps
- **Dark mode:** enabled via both GTK settings and dconf (`color-scheme = prefer-dark`) for libadwaita apps

### Icon theme

- **Theme:** Tela-dark (`pkgs.tela-icon-theme`)
- Note: COSMIC Files uses symbolic icons only — colored icon themes make no visual difference in the file manager. Tela-dark is a general preference for GTK apps that do respect icon themes.

---

## What NOT to Do

| Don't | Why |
|-------|-----|
| Manually edit `~/.config/cosmic/com.system76.CosmicBackground/v1/*` | RON format is strict; any parse error causes `cosmic-session` exponential backoff restart loops |
| Run `matugen color hex` directly with a wrong hex | The feedback loop prevention file caches the wrong wallpaper path, preventing future runs |
| Change the wallpaper by editing COSMIC config files | Set it through **COSMIC Settings → Desktop → Wallpaper** only |
| Run `matugen` while the service is also running | Two concurrent runs can produce partially-written template files |
| Edit `~/.config/matugen/config.toml` manually | The file has `force = true` — Home Manager overwrites it on every rebuild |
