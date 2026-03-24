# 🖥️ Desktop Environment

COSMIC is the desktop environment on all graphical machines in this config. It is System76's Rust-based DE, available natively in nixpkgs as of NixOS 25.05 — no external flake is needed. System-level setup lives in `modules/desktop-environments/cosmic.nix`; per-user config is written declaratively via `home.file` entries in each user's `home.nix`.

> ⚠️ Do not edit COSMIC config files manually while COSMIC is running. Config files are in RON (Rusty Object Notation) format. Writing to them while `cosmic-session` holds them open causes parse errors and exponential backoff restart loops. Use Home Manager to write them declaratively, then rebuild.

---

## 📋 Contents

- [Module Structure](#module-structure)
- [What the System Module Enables](#what-the-system-module-enables)
- [Shared Theme Module](#shared-theme-module)
- [Files Sidebar Favorites](#files-sidebar-favorites)
- [Wallpaper and Theming](#wallpaper-and-theming)
- [Flatpak](#flatpak)
- [Troubleshooting](#troubleshooting)

---

## 📁 Module Structure

[↑ Back to Contents](#-contents)

COSMIC configuration is split across three places:

| Location | What it controls |
|----------|-----------------|
| `modules/desktop-environments/cosmic.nix` | System-level: DE enable, display manager, XWayland, portals, Flatpak, Keyring, fonts |
| `modules/home/cosmic-theme.nix` | Shared HM module: cursor, icon theme, COSMIC appearance config files |
| `users/<user>/home.nix` | Per-user: Files sidebar favorites, Hytale install service, GTK settings |

`cosmic.nix` is imported by every desktop and laptop host config. It injects `wallpaper-slideshow.nix` and `cosmic-theme.nix` into all users automatically via `home-manager.sharedModules` — no need to import them in individual `home.nix` files.

---

## ⚙️ What the System Module Enables

[↑ Back to Contents](#-contents)

The following are set in `modules/desktop-environments/cosmic.nix`:

```nix
services.desktopManager.cosmic.enable = true;
services.displayManager.cosmic-greeter.enable = true;   # COSMIC's own login screen

programs.xwayland.enable = true;   # X11 compatibility layer for apps that don't support Wayland

# XDG portals — COSMIC first, GTK as fallback for apps that need it
xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-cosmic pkgs.xdg-desktop-portal-gtk ];
xdg.portal.config.common.default = "cosmic;gtk";

# Clipboard applet in the panel
environment.variables.COSMIC_DATA_CONTROL_ENABLED = "1";

# Flatpak backend for COSMIC Store
services.flatpak.enable = true;
services.packagekit.enable = true;   # needed for Store's "Installed" / "Updates" views

# Keyring — prevents repeated unlock prompts from Zed, browsers, and apps that use libsecret
services.gnome.gnome-keyring.enable = true;
security.pam.services.login.enableGnomeKeyring = true;
```

### System packages

The following community extension is installed system-wide:

| Package | Purpose |
|---------|---------|
| `cosmic-ext-applet-privacy-indicator` | Camera/mic/screen-share indicator in the panel |

COSMIC's own bundled apps (Files, Text Editor, Store, Terminal, etc.) are included automatically by `services.desktopManager.cosmic.enable` — they don't need to be listed explicitly.

### Fonts

System-wide fonts configured in the module:

| Package | Purpose |
|---------|---------|
| `noto-fonts` | Wide Unicode coverage |
| `noto-fonts-cjk-sans` | Chinese, Japanese, Korean |
| `noto-fonts-color-emoji` | Emoji |
| `liberation_ttf` | Free replacements for Arial, Times New Roman |
| `nerd-fonts.jetbrains-mono` | Nerd Font glyphs for terminal and editor icons |

Default font families: serif → `Noto Serif`, sans-serif → `Noto Sans`, monospace → `JetBrainsMono Nerd Font`.

---

## 🎨 Shared Theme Module

[↑ Back to Contents](#-contents)

`modules/home/cosmic-theme.nix` is injected into every user on every COSMIC host. It sets cursor, icons, and COSMIC appearance declaratively so all users start with the same look.

### Cursor

- **Theme:** BreezeX-Light
- **Size:** 24
- **Source:** Custom derivation fetching `BreezeX.tar.xz` from the `ful1e5/BreezeX_Cursor` GitHub releases (v2.0.1)
- **Applied via:** `home.pointerCursor` — sets `XCURSOR_THEME`/`XCURSOR_SIZE` in the systemd user environment, creates `~/.icons/default/index.theme` for X11 fallback, and writes GTK cursor config

### Icon theme

- **Theme:** Tela-dark (`pkgs.tela-icon-theme`)
- Note: COSMIC Files uses symbolic icons only — colored themes make no visual difference in the file manager. Tela-dark applies to GTK apps that do respect icon themes.

### COSMIC appearance config files

The module writes these files declaratively at activation time:

```
~/.config/cosmic/com.system76.CosmicTk/v1/icon_theme    → "Tela-dark"
~/.config/cosmic/com.system76.CosmicTk/v1/cursor_theme  → "BreezeX-Light"
~/.config/cosmic/com.system76.CosmicTk/v1/cursor_size   → 24
```

These are written as RON values. COSMIC reads them at session start so the theme is always consistent regardless of what the COSMIC GUI may have previously set.

---

## 📌 Files Sidebar Favorites

[↑ Back to Contents](#-contents)

COSMIC Files sidebar favorites are written declaratively via `home.file` for all three users. The config file lives at:

```
~/.config/cosmic/com.system76.CosmicFiles/v1/favorites
```

**Why only network shares are listed:** Local drives appear automatically in COSMIC Files' **Devices** section. Only network CIFS mounts need explicit entries to show up in the sidebar.

**Mount path capitalization matters:** The last path segment becomes the display name in COSMIC Files. `/mnt/Media-Server` shows as "Media-Server"; `/mnt/media-server` would show as "media-server".

### Per-user favorites

**linuxury** (`users/linuxury/home.nix`):

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
]
```

**babylinux** (`users/babylinux/home.nix`):

```ron
[
    Home,
    Documents,
    Downloads,
    Music,
    Pictures,
    Videos,
    Path("/mnt/Media-Server"),
]
```

**alex** (`users/alex/home.nix`):

```ron
[
    Home,
    Documents,
    Downloads,
    Music,
    Pictures,
    Videos,
    Path("/mnt/Media-Server"),
]
```

### Adding a new share

Edit the favorites block in the appropriate `home.nix`, then rebuild:

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
        Path("/mnt/NewShare"),    # ← add here
    ]
  '';
};
```

Then rebuild: `nr`

All CIFS mounts use `x-systemd.automount`, `idle-timeout=60`, and `nofail _netdev noauto` — missing or unreachable shares are silently skipped at boot. Safe on laptops not connected to the home network.

---

## 🖼️ Wallpaper and Theming

[↑ Back to Contents](#-contents)

Wallpaper rotation and dynamic color theming are handled by the matugen pipeline, which is injected into every COSMIC host automatically. The full pipeline is documented in [09-theming.md](09-theming.md).

Key rules for the DE:

- Set wallpapers only through **COSMIC Settings → Desktop → Wallpaper** — never by editing config files
- The wallpaper config lives at `~/.config/cosmic/com.system76.CosmicBackground/v1/` in RON format — manual edits corrupt the session
- `wallpaper-color-sync` (systemd path unit + timer) watches the COSMIC background config dir and runs matugen when the wallpaper changes

→ [Full theming pipeline in 09-theming.md](09-theming.md)

---

## 📦 Flatpak

[↑ Back to Contents](#-contents)

Flatpak is enabled system-wide via `services.flatpak.enable = true` in `cosmic.nix`. The Flathub remote is added at system scope during activation so COSMIC Store can browse apps.

PackageKit is also enabled so COSMIC Store's **Installed** and **Updates** views work. PackageKit has no Nix backend — it doesn't manage Nix packages — but the daemon must be present for Store to function.

### Hytale launcher

Hytale is not on Flathub. A one-shot systemd user service installs it from a pre-downloaded flatpak bundle on first login.

**Bundle path:** `~/Documents/assets/flatpaks/hytale-launcher-latest.flatpak`

**Condition:** The service only runs if the app is not already installed:

```
ConditionPathExists = !%h/.local/share/flatpak/app/com.hypixel.HytaleLauncher
```

**Per-user behavior:**

| User | Behavior |
|------|----------|
| linuxury | Tries local bundle first; falls back to CDN download if the file isn't present |
| babylinux | Local bundle required — service fails with a message if the file is missing |
| alex | Local bundle required — same as babylinux |

**linuxury Wayland fix:** The Hytale Electron launcher renders blank on COSMIC because it attempts native Wayland GPU rendering. A Home Manager activation script forces it to use XWayland instead:

```bash
flatpak override --user --env=ELECTRON_OZONE_PLATFORM_HINT=x11 com.hypixel.HytaleLauncher
```

This runs idempotently on every HM activation — it will always be correct after a rebuild.

**Alex's machines:** Flatpak is restricted on Alex's machines, but re-enabled specifically for the Hytale service in `hosts/Alex-Desktop` and `hosts/Alex-Laptop`.

### Checking install status

```bash
systemctl --user status hytale-flatpak-install        # check service status
journalctl --user -u hytale-flatpak-install -n 50     # view logs if it failed
flatpak list --user | grep Hytale                      # verify the app is installed
```

---

## 🆘 Troubleshooting

[↑ Back to Contents](#-contents)

### COSMIC desktop flashing / `cosmic-session` restarting in a loop

Most likely caused by a corrupted COSMIC config file — usually from a manual edit to the wallpaper config or an incomplete write. Find the error in session logs:

```bash
journalctl --user -u cosmic-session -n 100 | grep -i "error\|fail\|panic"
```

The fix is usually deleting or restoring the corrupt config file. For the wallpaper config:

```bash
# If the session won't start at all, switch to a TTY with Ctrl+Alt+F3, log in, then:
rm -rf ~/.config/cosmic/com.system76.CosmicBackground/
systemctl --user restart cosmic-session
# Then re-set the wallpaper via COSMIC Settings after the session recovers
```

---

### COSMIC Files shows wrong or missing network shares

Favorites are written declaratively by Home Manager. If they look wrong after a config change, rebuild:

```bash
nr   # applies the updated home.nix
```

To see what's actually on disk:

```bash
cat ~/.config/cosmic/com.system76.CosmicFiles/v1/favorites
```

Missing paths (e.g. a server that's off) are silently skipped — this is expected behavior, not an error.

---

### Display scaling looks wrong after first boot

COSMIC stores display settings per-monitor by EDID. Open **COSMIC Settings → Displays** and set your preferred scaling. The setting is remembered for that monitor going forward.

---

### Hytale launcher shows blank content on COSMIC

The Wayland fix (`ELECTRON_OZONE_PLATFORM_HINT=x11`) should have been applied by HM activation. Verify it's in place and re-apply if needed:

```bash
flatpak info --show-permissions --user com.hypixel.HytaleLauncher | grep ELECTRON
# Should show: ELECTRON_OZONE_PLATFORM_HINT=x11

# Re-apply if missing:
flatpak override --user --env=ELECTRON_OZONE_PLATFORM_HINT=x11 com.hypixel.HytaleLauncher
```

---

### Hytale flatpak install service failed

```bash
journalctl --user -u hytale-flatpak-install -n 50   # view the error
```

Common causes:

- **Bundle missing:** Place `hytale-launcher-latest.flatpak` in `~/Documents/assets/flatpaks/` and restart the service with `systemctl --user restart hytale-flatpak-install`
- **Flathub remote not added:** Run `flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo`
- **Already installed:** The condition check prevents re-runs — `flatpak list --user | grep Hytale` will confirm it's installed
