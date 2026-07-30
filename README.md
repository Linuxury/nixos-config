# Linuxury NixOS Configuration

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue.svg?style=flat&logo=nixos&logoColor=white)](https://nixos.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A fully declarative, modular NixOS setup using flakes — built for a 3-person family household across 6 desktops/laptops and 3 headless servers. Everything from disk partitioning to app configuration is version-controlled and reproducible.

---

## Contents

- [Highlights](#highlights)
- [Hosts](#hosts)
- [Structure](#structure)
- [Documentation](#documentation)

---

## Highlights

- **Hyprland** on linuxury's machines — tiling Wayland compositor with a full Lua config, matugen color theming, Waybar, swaync, and hypridle
- **COSMIC DE** on babylinux and alex's machines — System76's Rust-based desktop; config written declaratively via Home Manager
- **matugen theming** — wallpaper-driven color pipeline; terminal, editor, and desktop colors all update automatically when the wallpaper rotates
- **BTRFS everywhere** — `@`, `@home`, `@nix`, `@log`, `@cache`, `@snapshots`, and `@swap` subvolumes on every host
- **Automatic snapshots** — Snapper takes hourly, daily, and weekly snapshots of `/` and `/home`
- **ragenix secrets** — SSH keys, WireGuard config, and service passwords encrypted in the repo; no plaintext ever in version control
- **Firefox enterprise policies** — uBlock Origin, search engine, and privacy settings locked in declaratively
- **Gaming** — Steam, MangoHud, GameMode, Proton, and Hytale on all gaming machines
- **VPN-scoped qBittorrent** — WireGuard network namespace killswitch on Radxa-X4; IP leaks are structurally impossible
- **Media server** — Plex, Sonarr, Radarr, Prowlarr, Immich, and FreshRSS on dedicated hardware
- **Family Samba shares** — network shares auto-mounted on all desktops via CIFS + agenix credentials
- **Tailscale mesh** — all machines reachable by hostname from anywhere
- **Zsh + Starship + Kitty** — terminal environment with NixOS management abbreviations

---

## Hosts

| Host | User | Role | LUKS |
|------|------|------|------|
| **ThinkPad** | linuxury | Laptop (Hyprland) | ✅ |
| **Ryzen5900x** | linuxury | Desktop (Hyprland) | ❌ |
| **Ryzen5800x** | babylinux | Desktop (COSMIC) | ❌ |
| **Asus-A15** | babylinux | Laptop (COSMIC) | ✅ |
| **Alex-Desktop** | alex | Kid's desktop (COSMIC) | ❌ |
| **Alex-Laptop** | alex | Kid's laptop (COSMIC) | ❌ |
| **Media-Server** | — | Plex · Arr stack · Immich · FreshRSS | ❌ |
| **Radxa-X4** | — | Torrent (Mullvad VPN killswitch) | ❌ |
| **MinisForum** | — | Game servers (Minecraft · Hytale) | ❌ |

---

## Structure

```
nixos-config/
├── flake.nix                    # Entry point — all hosts defined here
├── hosts/                       # Per-host system configuration
│   ├── ThinkPad/
│   ├── Ryzen5900x/
│   ├── Ryzen5800x/
│   ├── Asus-A15/
│   ├── Alex-Desktop/
│   ├── Alex-Laptop/
│   ├── Media-Server/
│   ├── Radxa-X4/
│   └── MinisForum/
├── modules/
│   ├── system/                  # Core kernel settings, graphical base, server shell
│   ├── compositors/             # Hyprland, Niri
│   ├── desktops/                # COSMIC DE, GNOME, KDE
│   ├── hardware/                # GPU driver logic (AMD / Nvidia / Intel)
│   ├── services/                # Samba, Syncthing, Snapper, wallpaper slideshow, VPN
│   ├── gaming/                  # Steam, MangoHud, GameMode
│   ├── development/             # Dev tools
│   ├── shells/                  # Zsh configuration
│   ├── greeters/                # SDDM + Catppuccin theme
│   ├── themes/                  # GTK theming
│   ├── components/              # Shared UI components (Home Manager modules)
│   └── users/                   # Per-user system-level setup (description, groups)
├── users/                       # Home Manager configs
│   ├── linuxury/home.nix
│   ├── babylinux/home.nix
│   └── alex/home.nix
├── dotfiles/                    # Config files symlinked by Home Manager
│   ├── hypr/                    # Hyprland, hyprlock, hypridle (Lua)
│   ├── waybar/                  # Status bar config + matugen color templates
│   ├── swaync/                  # Notification center + matugen color templates
│   ├── kitty/                   # Terminal emulator
│   ├── zsh/                     # Shared zsh init and completions
│   ├── starship/                # Prompt config
│   ├── MangoHud/                # Performance overlay config
│   ├── nvim-extra/              # Neovim extras
│   └── ...                      # rofi, wofi, vscodium, opencode, swappy, topgrade
├── secrets/                     # age-encrypted secrets (safe to commit)
│   ├── secrets.nix              # Access control — who can read what
│   └── *.age                    # Encrypted secret files
├── assets/                      # Wallpapers, avatars, SteamGridDB art, flatpak bundles
└── docs/                        # Documentation (see below)
```

---

## Documentation

**Installation — pick one based on your hardware:**

| # | File | Boot mode | Encryption |
|---|------|-----------|------------|
| 01 | [Getting Started](docs/01-getting-started.md) | — | — |
| 02 | [Install: UEFI](docs/02-install-uefi.md) | UEFI | None |
| 03 | [Install: LUKS](docs/03-install-luks.md) | UEFI | LUKS full-disk |
| 04 | [Install: Legacy BIOS](docs/04-install-legacy-bios.md) | Legacy BIOS | None |
| 05 | [Install: Legacy BIOS + LUKS](docs/05-install-legacy-luks.md) | Legacy BIOS | LUKS full-disk |

**Reference:**

| # | File | What it covers |
|---|------|----------------|
| 06 | [First Boot](docs/06-first-boot.md) | Tailscale, SSH keys, secrets, assets, per-host steps |
| 07 | [Flake & Module Reference](docs/07-flake-guide.md) | Config structure, mkHost, adding hosts and packages |
| 08 | [Secrets Management](docs/08-secrets.md) | ragenix workflow, secrets.nix, creating and re-keying secrets |
| 09 | [Maintenance](docs/09-maintenance.md) | Rebuilds, updates, snapshots, rollback, garbage collection |
| 10 | [Server Management](docs/10-servers.md) | Media-Server, Radxa-X4, MinisForum — services and operations |
| 11 | [Applications](docs/11-applications.md) | Neovim, Kitty, Ghostty, Zsh, Helix, Zed, and more |
| 12 | [Gaming](docs/12-gaming.md) | Proton-GE, Steam, MangoHud, Hytale, launch options |
| 13 | [Theming](docs/13-theming.md) | matugen pipeline, Hyprland and COSMIC color sync |
| 14 | [Desktop Environment](docs/14-de-wm.md) | COSMIC DE config, Hyprland setup, sidebar favorites, Flatpak |
| 15 | [Troubleshooting](docs/15-troubleshooting.md) | Common failures and fixes across all areas |

---

## License

MIT — feel free to use and adapt for your own systems.
