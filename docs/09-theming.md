# 🎨 Theming

How the dynamic theming pipeline works — wallpaper rotation, matugen color generation, and COSMIC customization. The system automatically adapts terminal, editor, and app colors to match the current wallpaper without any manual steps.

---

## 📋 Contents

- [Overview](#overview)
- [Wallpapers](#wallpapers)
- [matugen](#matugen)
- [wallpaper-color-sync Service](#wallpaper-color-sync-service)
- [COSMIC Configuration](#cosmic-configuration)
- [Cursor and Icons](#cursor-and-icons)
- [What NOT to Do](#what-not-to-do)

---

## 🖼️ Overview

[↑ Back to Contents](#-contents)

The theming pipeline runs automatically in the background. When the wallpaper changes, terminal colors, editor colors, and any other apps with matugen templates update to match — no restart or manual step required.

```
COSMIC wallpaper rotation
        ↓
wallpaper-color-sync (systemd path unit watches COSMIC config dir)
        ↓
Reads current wallpaper path from COSMIC's config
        ↓
Checks last-run cache — skips if wallpaper hasn't changed
        ↓
Extracts dominant color via ImageMagick
        ↓
matugen generates a full Material You color palette
        ↓
Writes colors to template outputs:
  ~/.config/kitty/colors.conf       (Kitty terminal)
  ~/.config/nvim/lua/utils/matugen-colors.lua (Neovim colorscheme)
  + any other configured templates
```

---

## 🖼️ Wallpapers

[↑ Back to Contents](#-contents)

### Source locations

| User | Wallpaper source | Symlinked to |
|------|-----------------|--------------|
| linuxury | `~/nixos-config/assets/Wallpapers/<dir>/` | `~/Pictures/Wallpapers/` |
| babylinux | `~/assets/Wallpapers/<dir>/` | `~/Pictures/Wallpapers/` |
| alex | `~/assets/Wallpapers/<dir>/` | `~/Pictures/Wallpapers/` |

The `<dir>` is the `wallpaperDir` from `flake.nix`:

| Host | wallpaperDir |
|------|-------------|
| ThinkPad | `4k` |
| Ryzen5900x | `3440x1440` |
| Ryzen5800x, Asus-A15 | `4k` |
| Alex-Desktop, Alex-Laptop | `PikaOS` |

### Setting the wallpaper

Set wallpapers and configure the slideshow via **COSMIC Settings → Desktop → Wallpaper**. COSMIC handles the rotation interval and order.

> ⚠️ Do not edit COSMIC's wallpaper config files directly. COSMIC writes them in RON (Rusty Object Notation) format. Any manual edit — even a minor formatting change — can corrupt the file and cause `cosmic-session` to enter exponential backoff restart loops. Use the COSMIC Settings GUI only.

---

## 🎨 matugen

[↑ Back to Contents](#-contents)

**matugen** is a Material You color scheme generator. It takes a wallpaper image and produces a full color palette based on the dominant colors, then writes that palette into template files.

Material You is the design language used in Android 12+ — the idea is that the whole system's color scheme derives from a single source image rather than a static theme choice.

### Templates

Templates are cloned from the community template repo into the nixos-config:

```
dotfiles/matugen/templates/   ← git clone of InioX/matugen-themes
```

Home Manager auto-clones this directory if it's missing (via `home.activation.matugenTemplates`). You don't need to clone it manually.

**matugen config:** `~/.config/matugen/config.toml` — written declaratively by Home Manager with `force = true` so it always reflects the current config.

### Seed files

One empty seed file is pre-created by Home Manager activation before matugen first runs:

- `~/.config/kitty/colors.conf`

This must exist before matugen runs — otherwise matugen errors trying to write to a nonexistent path. Home Manager creates it so the pipeline works from the first wallpaper change.

---

## ⚙️ wallpaper-color-sync Service

[↑ Back to Contents](#-contents)

Two systemd user units work together to trigger matugen when the wallpaper changes.

### `wallpaper-color-sync.path`

Watches `~/.config/cosmic/com.system76.CosmicBackground/v1/` for file changes. When COSMIC writes a wallpaper update to that directory, the path unit immediately triggers the service.

### `wallpaper-color-sync.timer`

Fires on login and every 10 minutes. This catches wallpaper rotations where COSMIC updates in-place without writing a new file (which doesn't trigger the path unit).

### What the service does

1. Reads the current wallpaper path from COSMIC's `all` config file
2. Compares it to `~/.local/share/last-matugen-wallpaper` — if they match, skips (feedback loop prevention)
3. Extracts the dominant color using ImageMagick: `convert wallpaper.jpg -resize 1x1 txt:-`
4. Runs `matugen image <wallpaper-path>` — writes all template outputs
5. Saves the wallpaper path to `~/.local/share/last-matugen-wallpaper`

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

## 🖥️ COSMIC Configuration

[↑ Back to Contents](#-contents)

COSMIC settings are written declaratively via `home.file` in each user's `home.nix`. These are plain text files placed at the appropriate paths under `~/.config/cosmic/`.

> ⚠️ These files are written at build/activation time. Do not edit them manually while COSMIC is running — COSMIC holds the files open and manual edits cause parse errors.

### Files sidebar favorites

Defined in `home.file.".config/cosmic/com.system76.CosmicFiles/v1/favorites"` for all three users.

Only network shares appear in this file. Local drives (XFS data drives, etc.) show up automatically in COSMIC's **Devices** section and don't need explicit entries.

Mount path capitalization matters for display — the last path segment becomes the label shown in the sidebar:

```
/mnt/Media-Server    ✓ (displays as "Media-Server")
/mnt/media-server    ✗ (would display as "media-server")
```

Favorites per user:

- **linuxury:** standard dirs + `/mnt/Media-Server` + `/mnt/MinisForum`
- **babylinux:** standard dirs + `/mnt/Media-Server`
- **alex:** standard dirs + `/mnt/Media-Server`

### Adding a new favorite

Edit the favorites block in the appropriate `home.nix`, then rebuild:

```nix
home.file.".config/cosmic/com.system76.CosmicFiles/v1/favorites".text = ''
  Path("/home/linuxury")
  Path("/home/linuxury/Documents")
  Path("/mnt/Media-Server")
  Path("/mnt/NewShare")   # ← add here
'';
```

Then rebuild: `nr`

---

## 🖱️ Cursor and Icons

[↑ Back to Contents](#-contents)

### Cursor

- **Theme:** BreezeX-Light
- **Source:** Custom Nix derivation that fetches the cursor package from the `ful1e5/BreezeX_Cursor` GitHub releases
- **Applied via:** `home.pointerCursor` in `modules/home/cosmic-theme.nix` — sets `XCURSOR_THEME`/`XCURSOR_SIZE` in the systemd user environment, creates `~/.icons/default/index.theme` for X11 fallback, and writes GTK cursor config
- **Size:** 24

### Icon theme

- **Theme:** Tela-dark (`pkgs.tela-icon-theme`)
- Note: COSMIC Files uses symbolic icons only — colored icon themes make no visual difference in the file manager. Tela-dark is a general preference for GTK apps that do respect icon themes.

---

## 🛑 What NOT to Do

[↑ Back to Contents](#-contents)

| Don't | Why |
|-------|-----|
| Manually edit `~/.config/cosmic/com.system76.CosmicBackground/v1/*` | RON format is strict; any parse error causes `cosmic-session` exponential backoff restart loops |
| Run `matugen` directly with a wrong path | The feedback loop prevention file caches the wrong path, preventing future runs from picking up the real wallpaper |
| Change the wallpaper by editing COSMIC config files | Set it through **COSMIC Settings → Desktop → Wallpaper** only |
| Run `matugen` while the service is also running | Two concurrent runs can produce partially-written template files |
