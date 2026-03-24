# NixOS Config — File Audit (2026-03-23)

**Total files:** 1343 (120 config, 1223 assets)
**Nix files:** 50 | **Dotfiles:** 73 | **Docs:** 11

---

## Hosts (9 hosts)

| File | Status | Notes |
|------|--------|-------|
| `hosts/ThinkPad/default.nix` | ✅ Reviewed | Active — linuxury laptop |
| `hosts/Ryzen5900x/default.nix` | ✅ Reviewed | Active — linuxury desktop |
| `hosts/Ryzen5800x/default.nix` | ✅ Reviewed | Active — babylinux desktop |
| `hosts/Asus-A15/default.nix` | ⚠️ TODO | L62: `TODO: switch back to nvidia-hybrid once PCI bus IDs are filled in` |
| `hosts/Alex-Desktop/default.nix` | ✅ Reviewed | Active — alex kid's desktop |
| `hosts/Alex-Laptop/default.nix` | ✅ Reviewed | Active — alex kid's laptop |
| `hosts/MinisForum/default.nix` | ✅ Reviewed | Active — mini PC server |
| `hosts/Radxa-X4/default.nix` | ✅ Reviewed | Active — SBC |
| `hosts/Media-Server/default.nix` | ✅ Reviewed | Active — media server |

---

## Modules — Base (10 files)

| File | Status | Notes |
|------|--------|-------|
| `modules/base/common.nix` | ✅ Reviewed | Core shared config |
| `modules/base/graphical-base.nix` | ✅ Reviewed | Shared graphical packages, fonts, GVfs |
| `modules/base/linuxury-description.nix` | ✅ Reviewed | User description + avatar |
| `modules/base/alex-description.nix` | ✅ Reviewed | User description |
| `modules/base/babylinux-description.nix` | ✅ Reviewed | User description |
| `modules/base/linuxury-ssh.nix` | ✅ Reviewed | SSH keys |
| `modules/base/firefox.nix` | ✅ Reviewed | Firefox policies |
| `modules/base/auto-update.nix` | ✅ Reviewed | Auto-update + cleanup |
| `modules/base/server-shell.nix` | ✅ Reviewed | Server-only shell config |
| `modules/base/snapper.nix` | ✅ Reviewed | BTRFS snapshots |
| `modules/base/torrents-precheck.nix` | ✅ Reviewed | CIFS mount pre-check |

---

## Modules — Desktop Environments (4 files)

| File | Status | Notes |
|------|--------|-------|
| `modules/desktop-environments/hyprland.nix` | ✅ Reviewed | Primary DE — linuxury |
| `modules/desktop-environments/cosmic.nix` | ✅ Reviewed | Default DE for family machines |
| `modules/desktop-environments/kde.nix` | ✅ Reviewed | KDE module |
| `modules/desktop-environments/niri.nix` | ✅ Reviewed | Niri WM module |

---

## Modules — Services (6 files)

| File | Status | Notes |
|------|--------|-------|
| `modules/services/hypr-matugen.nix` | ✅ Reviewed | Matugen theming pipeline |
| `modules/services/samba.nix` | ✅ Reviewed | Samba file sharing |
| `modules/services/syncthing.nix` | ✅ Reviewed | Syncthing sync |
| `modules/services/vpn-qbittorrent.nix` | ✅ Reviewed | VPN + qBittorrent |
| `modules/services/local-llm.nix` | ✅ Reviewed | Local LLM (Ollama) |
| `modules/services/wallpaper-slideshow.nix` | ✅ Reviewed | Wallpaper rotation |

---

## Modules — Other (5 files)

| File | Status | Notes |
|------|--------|-------|
| `modules/gaming/gaming.nix` | ⚠️ TODO | L158: `TODO: Remove discord once XMPP server is set up` |
| `modules/development/development.nix` | ✅ Reviewed | Dev tools |
| `modules/hardware/drivers.nix` | ✅ Reviewed | GPU driver abstraction |
| `modules/home/neovim.nix` | ✅ Reviewed | Neovim via normie-nvim |
| `modules/home/cosmic-theme.nix` | ✅ Reviewed | COSMIC theme |

---

## Modules — Users (3 files)

| File | Status | Notes |
|------|--------|-------|
| `modules/users/linuxury-packages.nix` | ⚠️ Duplication | Contains `onlyoffice-desktopeditors` — duplicated in all 3 user files |
| `modules/users/alex-packages.nix` | ⚠️ Duplication | Contains `onlyoffice-desktopeditors` — should be in graphical-base.nix |
| `modules/users/babylinux-packages.nix` | ⚠️ Duplication | Contains `onlyoffice-desktopeditors` — should be in graphical-base.nix |

---

## Dotfiles — Hyprland (28 files)

| File | Status | Notes |
|------|--------|-------|
| `dotfiles/hypr/hyprland.conf` | ✅ Reviewed | Main Hyprland config |
| `dotfiles/hypr/hyprlock.conf` | ✅ Reviewed | Lock screen |
| `dotfiles/hypr/hypridle.conf` | ✅ Reviewed | Idle daemon |
| `dotfiles/hypr/colors.conf` | ✅ Reviewed | Matugen colors (generated) |
| `dotfiles/hypr/colors-hyprlock.conf` | ✅ Reviewed | Hyprlock-specific colors |
| `dotfiles/hypr/modules/appearance.conf` | ✅ Reviewed | Visual settings |
| `dotfiles/hypr/modules/autostart.conf` | ✅ Reviewed | Startup apps |
| `dotfiles/hypr/modules/environment.conf` | ✅ Reviewed | Env vars |
| `dotfiles/hypr/modules/input.conf` | ✅ Reviewed | Keyboard/mouse |
| `dotfiles/hypr/modules/keybinds.conf` | ✅ Reviewed | Keybindings |
| `dotfiles/hypr/modules/monitors.conf` | ✅ Reviewed | Monitor config |
| `dotfiles/hypr/modules/windowrules.conf` | ✅ Reviewed | Window/layer rules |
| `dotfiles/hypr/scripts/*.sh` (10) | ✅ Reviewed | All scripts active |
| `dotfiles/hypr/swaync/config.json` | ✅ Reviewed | Notification daemon |
| `dotfiles/hypr/swaync/style.css` | ✅ Reviewed | Notification styling |
| `dotfiles/hypr/wob/wob.ini` | ❌ **DEAD** | wob was removed — this config is orphaned. **DELETE** |
| `dotfiles/hypr/wofi/config` | ✅ Reviewed | Launcher config |
| `dotfiles/hypr/wofi/style.css` | ✅ Reviewed | Launcher styling |
| `dotfiles/hypr/wofi/colors.css` | ✅ Reviewed | Launcher colors |
| `dotfiles/hypr/wofi/powermenu-style.css` | ✅ Reviewed | Power menu styling |

---

## Dotfiles — Neovim (17 files)

| File | Status | Notes |
|------|--------|-------|
| `dotfiles/nvim/` (12 files) | ❌ **DEAD** | Entire directory unused — normie-nvim flake replaces it. **DELETE** |
| `dotfiles/nvim-extra/lua/plugins/claude-code.lua` | ✅ Reviewed | Custom Claude Code overlay |
| `dotfiles/nvim-extra/lua/plugins/colortheme.lua` | ✅ Reviewed | Color theme overlay |
| `dotfiles/nvim-extra/lua/plugins/matugen.lua` | ✅ Reviewed | Matugen integration |
| `dotfiles/nvim-extra/lua/plugins/opencode.lua` | ✅ Reviewed | OpenCode integration |
| `dotfiles/nvim-extra/lua/utils/theme.lua` | ✅ Reviewed | Theme utilities |

---

## Dotfiles — Waybar (8 files)

| File | Status | Notes |
|------|--------|-------|
| `dotfiles/hypr/waybar/config.jsonc` | ✅ Reviewed | Main config |
| `dotfiles/hypr/waybar/style.css` | ✅ Reviewed | Styling |
| `dotfiles/hypr/waybar/colors.css` | ✅ Reviewed | Colors (generated) |
| `dotfiles/hypr/waybar/colors.css.template` | ✅ Reviewed | Matugen template |
| `dotfiles/hypr/waybar/scripts/clock.sh` | ✅ Reviewed | Clock module |
| `dotfiles/hypr/waybar/scripts/powermenu.sh` | ✅ Reviewed | Power menu button |
| `dotfiles/hypr/waybar/scripts/sysinfo.sh` | ✅ Reviewed | System info |
| `dotfiles/hypr/waybar/scripts/updates.sh` | ✅ Reviewed | Update checker |

---

## Dotfiles — Other (10 files)

| File | Status | Notes |
|------|--------|-------|
| `dotfiles/fastfetch/config.jsonc` | ✅ Reviewed | Active config |
| `dotfiles/fastfetch/config.jsonc.bak` | ❌ **DEAD** | Backup file — **DELETE** |
| `dotfiles/kitty/kitty.conf` | ✅ Reviewed | Terminal config |
| `dotfiles/kitty/hyprland-overrides.conf` | ✅ Reviewed | Per-host overrides |
| `dotfiles/starship/starship.toml` | ✅ Reviewed | Shell prompt |
| `dotfiles/MangoHud/MangoHud.conf` | ✅ Reviewed | Gaming overlay |
| `dotfiles/nano/.nanorc` | ✅ Reviewed | Nano config |
| `dotfiles/swappy/config` | ✅ Reviewed | Screenshot editor |
| `dotfiles/topgrade/topgrade-nixos.toml` | ✅ Reviewed | Update tool |
| `dotfiles/zed/settings.json` | ✅ Reviewed | Zed editor |
| `dotfiles/zsh/zshrc` | ✅ Reviewed | Shell config |

---

## Docs (11 files)

| File | Status |
|------|--------|
| `docs/01-installation.md` | ✅ Reviewed |
| `docs/02-first-boot.md` | ✅ Reviewed |
| `docs/03-flake-guide.md` | ✅ Reviewed |
| `docs/04-secrets.md` | ✅ Reviewed |
| `docs/05-maintenance.md` | ✅ Reviewed |
| `docs/06-servers.md` | ✅ Reviewed |
| `docs/07-applications.md` | ✅ Reviewed |
| `docs/08-gaming.md` | ✅ Reviewed |
| `docs/09-theming.md` | ✅ Reviewed |
| `docs/10-de-wm.md` | ✅ Reviewed |
| `docs/11-troubleshooting.md` | ✅ Reviewed |

---

## Issues Found

### Dead files — safe to delete
1. **`dotfiles/hypr/wob/wob.ini`** — wob removed, overlay now via swaync
2. **`dotfiles/fastfetch/config.jsonc.bak`** — stale backup
3. **`dotfiles/nvim/`** (entire directory, 12 files) — normie-nvim flake replaces it; rsync copies from flake input, not this directory

### Duplicated code
1. **`onlyoffice-desktopeditors`** — appears in all 3 user package files. Move to `graphical-base.nix` or a new shared module

### Open TODOs
1. **`hosts/Asus-A15/default.nix:62`** — `TODO: switch back to nvidia-hybrid once PCI bus IDs are filled in`
2. **`modules/gaming/gaming.nix:158`** — `TODO: Remove discord once XMPP server is set up`

### Suggested extraction (shared packages)
Current user-specific packages that could be shared:

| Package | Currently in | Suggestion |
|---------|-------------|------------|
| `onlyoffice-desktopeditors` | all 3 user files | Move to `graphical-base.nix` |
| `imagemagick` | linuxury only | Could be in `graphical-base.nix` (used by scripts) |

---

## Summary

- **120 config files** reviewed
- **4 dead files** to delete (wob.ini, fastfetch backup, nvim/ directory)
- **1 duplication** to fix (onlyoffice)
- **2 TODOs** to address
- **0 misplaced modules** — structure is clean
- **Documentation**: up to date (docs/ covers all major topics)
