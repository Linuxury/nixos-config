# Theming

How the dynamic theming pipeline works per desktop environment — wallpaper handling, matugen color generation, and appearance configuration. Each DE/compositor has its own pipeline; pick the section that matches the host you're working on.

---

## Contents

- [Desktop Map](#desktop-map)
- [Wallpapers](#wallpapers)
- [COSMIC Pipeline — wallpaper-color-sync](#cosmic-pipeline--wallpaper-color-sync)
- [Hyprland Pipeline — matugen service](#hyprland-pipeline--matugen-service)
- [KDE Plasma — babylinux](#kde-plasma--babylinux)
- [COSMIC Configuration](#cosmic-configuration)
- [Cursor and Icons](#cursor-and-icons)
- [What NOT to Do](#what-not-to-do)

---

## Desktop Map

Each host runs a specific DE or compositor. Use this table to find the right theming section:

| Host | Owner | Desktop | Theming pipeline |
|------|-------|---------|-----------------|
| ThinkPad | linuxury | COSMIC | [COSMIC pipeline](#cosmic-pipeline--wallpaper-color-sync) |
| Ryzen5900x | linuxury | Hyprland + Noctalia | [Hyprland pipeline](#hyprland-pipeline--matugen-service) |
| Ryzen5800x | babylinux | KDE Plasma 6 | [KDE Plasma](#kde-plasma--babylinux) |
| Asus-A15 | babylinux | KDE Plasma 6 | [KDE Plasma](#kde-plasma--babylinux) |
| Alex-Desktop | alex | COSMIC | [COSMIC pipeline](#cosmic-pipeline--wallpaper-color-sync) |
| Alex-Laptop | alex | COSMIC | [COSMIC pipeline](#cosmic-pipeline--wallpaper-color-sync) |

---

## Wallpapers

### Source locations

All users symlink wallpapers from the nixos-config repo:

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

---

## COSMIC Pipeline — wallpaper-color-sync

**Applies to:** ThinkPad (linuxury), Alex-Desktop, Alex-Laptop (alex)

Module: `modules/services/wallpaper-slideshow/default.nix` — injected into every user on every COSMIC host automatically via `home-manager.sharedModules` in `modules/desktops/cosmic/default.nix`.

### How it works

```
COSMIC wallpaper slideshow rotation
        ↓
wallpaper-color-sync (systemd path unit watches COSMIC config dir)
        ↓
Reads current wallpaper path from COSMIC's per-output or "all" config file
        ↓
Checks last-run cache — skips if wallpaper hasn't changed
        ↓
Extracts dominant color via ImageMagick: convert img -resize 1x1 -format "%[hex:u]" info:
        ↓
matugen color hex "#<HEX>" generates a full Material You color palette
        ↓
Writes colors to template outputs:
  ~/.config/starship-colors.toml                     (Starship prompt)
  ~/.config/gtk-4.0/colors.css                       (GTK4 apps)
  ~/.config/matugen/themes/matugen_cosmic.theme.ron  (COSMIC appearance)
  ~/.config/kitty/colors.conf                        (Kitty terminal)
  ~/.config/btop/themes/matugen.theme                (btop)
  ~/.config/zed/themes/matugen.json                  (Zed editor)
  ~/.config/mango/config.conf                        (MangoWC bar)
```

### Setting the wallpaper

Set wallpapers and configure the slideshow via **COSMIC Settings → Desktop → Wallpaper**. COSMIC handles the rotation interval and order.

> Do not edit COSMIC's wallpaper config files directly. COSMIC writes them in RON (Rusty Object Notation) format. Any manual edit — even a minor formatting change — can corrupt the file and cause `cosmic-session` to enter exponential backoff restart loops. Use the COSMIC Settings GUI only.

### wallpaper-color-sync.path

Watches `~/.config/cosmic/com.system76.CosmicBackground/v1/` for file changes. When COSMIC writes a wallpaper update to that directory, the path unit immediately triggers the service.

### wallpaper-color-sync.timer

Fires 30 seconds after session start, then every 10 minutes. Catches wallpaper rotations where COSMIC rotates through a directory source without writing a new config file.

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

If colors are stuck on an old wallpaper:

```bash
rm ~/.local/share/last-matugen-wallpaper        # clear the cache
systemctl --user restart wallpaper-color-sync   # run matugen unconditionally
```

---

## Hyprland Pipeline — matugen service

**Applies to:** Ryzen5900x (linuxury, Noctalia shell)

Module: `modules/compositors/hyprland/matugen/default.nix` — injected via `home-manager.sharedModules` in `modules/compositors/hyprland/default.nix`.

### How it works

```
Noctalia shell changes wallpaper
        ↓
Writes current wallpaper path to ~/.local/share/current-wallpaper
        ↓
matugen.path (systemd path unit watches that file)
        ↓
Checks last-run cache — skips if wallpaper hasn't changed (and colors.lua exists)
        ↓
Extracts dominant color via ImageMagick
        ↓
matugen color hex "#<HEX>" generates a full Material You color palette
        ↓
Writes colors to template outputs:
  ~/.config/hypr/colors.lua                    (Hyprland border/accent colors)
  ~/.config/kitty/colors.conf                  (Kitty terminal)
  ~/.config/gtk-4.0/colors.css                 (GTK4 apps)
  ~/.config/gtk-4.0/libadwaita-matugen.css     (libadwaita apps)
  ~/.config/rofi/window.rasi                   (Rofi launcher)
  ~/.config/hypr/colors-hyprlock.conf          (Hyprlock screen lock)
        ↓
apply_borders: updates Hyprland active/inactive border colors live via hyprctl keyword
        ↓
Syncs wallpaper to SDDM login screen (/var/lib/sddm-wallpaper/background.jpg)
```

### matugen.path

Watches `~/.local/share/current-wallpaper`. The Noctalia shell writes this file when the wallpaper changes, decoupling matugen from any specific shell implementation.

### matugen.timer

Fires 10 seconds after session start. Gives the shell time to initialize and set the first wallpaper before matugen queries it.

### noctalia-color-sync (Noctalia shell only)

Module: `modules/shells/noctalia/color-sync/default.nix` — imported automatically by the Noctalia shell module.

A separate path unit watches `~/.config/noctalia/colors.json`. Noctalia writes that file whenever it derives a new accent color from the wallpaper. The service reads `mPrimary` from the JSON and patches MangoWC's `focuscolor` in `~/.config/mango/config.conf` directly, then reloads via `mmsg -d reload_config`.

This is a faster, targeted update — it sets the focus border immediately on accent change without waiting for the full matugen run.

### GTK4 Noctalia accent CSS

Noctalia also writes `~/.config/gtk-4.0/noctalia.css` with the current accent color. Both the Hyprland and MangoWC theme modules import it via `gtk.gtk4.extraCss = '@import url("noctalia.css");'` so GTK4 apps follow the active accent.

### Checking the service

```bash
systemctl --user status matugen                  # check matugen service
systemctl --user status noctalia-color-sync      # check focus-border sync
journalctl --user -u matugen -f                  # follow live matugen logs
```

Service logs: `~/.local/share/wallpaper-service.log`

### Forcing a color refresh

```bash
rm ~/.local/share/last-matugen-processed   # clear the deduplication stamp
systemctl --user restart matugen           # run matugen unconditionally
```

---

## KDE Plasma — babylinux

**Applies to:** Ryzen5800x, Asus-A15 (babylinux)

KDE Plasma manages its own theming — there is no matugen pipeline on these hosts. Wallpapers and colors are set through KDE System Settings.

### Appearance configuration

| Setting | Value |
|---------|-------|
| Icon theme | `breeze-chameleon-dark` |
| Color scheme | `BreezeDark` |
| Look and feel | `org.kde.breezedark.desktop` |
| Window decoration / app style | `darkly` |
| Cursor theme | `BreezeX-Light` (size 24) |
| Qt theme engine | Kvantum (`ant-dark-kde`) |

These are written by a Home Manager activation script (`home.activation.initKdeConfig`) to `kdeglobals` and `kcminputrc` if the files don't already exist — KDE manages them from there.

### SDDM wallpaper sync

KDE has its own login-screen wallpaper sync service:

- Service name: `sddm-wallpaper-sync`
- Triggers: once at graphical-session.target start
- Reads the current wallpaper from `~/.config/plasma-org.kde.plasma.desktop-appletsrc`
- Writes it to `/var/lib/sddm-wallpaper/background.jpg`

This keeps the SDDM login screen in sync with the KDE desktop wallpaper after each login.

### Setting the wallpaper

Set wallpapers through **KDE System Settings → Wallpaper** or by right-clicking the desktop. KDE handles its own rotation and display.

---

## matugen — Shared Setup

The following applies to all hosts that use a matugen pipeline (COSMIC and Hyprland):

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

This must exist before matugen runs — otherwise matugen errors trying to write to a nonexistent path.

---

## COSMIC Configuration

**Applies to:** ThinkPad (linuxury), Alex-Desktop, Alex-Laptop (alex)

Module: `modules/desktops/cosmic/themes/default.nix` — injected via `home-manager.sharedModules` in `modules/desktops/cosmic/default.nix`.

### COSMIC appearance config files

Written declaratively at activation time:

```
~/.config/cosmic/com.system76.CosmicTk/v1/icon_theme    → "Tela-dark"
~/.config/cosmic/com.system76.CosmicTk/v1/cursor_theme  → "BreezeX-Light"
~/.config/cosmic/com.system76.CosmicTk/v1/cursor_size   → 24
```

### Files sidebar favorites

All COSMIC users get the same favorites from the shared themes module:

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

Only network shares appear in this file. Local drives show up automatically in COSMIC's **Devices** section. Mount path capitalization matters — the last path segment becomes the display label.

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

Cursor and base GTK theme are defined in `modules/themes/gtk/default.nix`, imported by every compositor and desktop theme module.

### Cursor — all hosts

- **Theme:** BreezeX-Light
- **Source:** Custom Nix derivation fetching `BreezeX.tar.xz` from `ful1e5/BreezeX_Cursor` GitHub releases (v2.0.1)
- **Applied via:** `home.pointerCursor` — sets `XCURSOR_THEME`/`XCURSOR_SIZE` in the systemd user environment, creates `~/.icons/default/index.theme` for X11 fallback
- **Size:** 24

### GTK theme — COSMIC and Hyprland hosts

- **GTK theme:** adw-gtk3-dark (`pkgs.adw-gtk3`)
- **Icon theme:** Tela-dark (`pkgs.tela-icon-theme`)
- **Dark mode:** enabled via GTK settings and dconf (`color-scheme = prefer-dark`) for libadwaita apps

### Icon and color theme — KDE hosts (babylinux)

KDE manages its own theming layer on top of the shared cursor:

- **Icon theme:** breeze-chameleon-dark (adaptive folder colors)
- **Color scheme:** BreezeDark
- **Window decoration:** darkly
- **GTK integration:** KDE manages GTK theming directly (`gtk.enable = false` on the pointer cursor config); `QT_QPA_PLATFORMTHEME = "kde"` set system-wide

---

## What NOT to Do

| Don't | Why |
|-------|-----|
| Manually edit `~/.config/cosmic/com.system76.CosmicBackground/v1/*` | RON format is strict; any parse error causes `cosmic-session` exponential backoff restart loops |
| Run `matugen color hex` directly with a wrong hex | The deduplication stamp caches the wrong path, preventing the next real run |
| Change the wallpaper on COSMIC by editing config files | Use **COSMIC Settings → Desktop → Wallpaper** only |
| Run `matugen` while the service is also running | Two concurrent runs produce partially-written template files |
| Edit `~/.config/matugen/config.toml` manually | The file has `force = true` — Home Manager overwrites it on every rebuild |
