# 🏠 Linuxury NixOS Configuration

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue.svg?style=flat&logo=nixos&logoColor=white)](https://nixos.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A fully declarative, modular NixOS setup using flakes — built for a 3-person family household across 6 desktops/laptops and 3 headless servers. Everything from disk partitioning to app configuration is version-controlled and reproducible.

---

## ✨ Highlights

- 🖥️ **COSMIC DE** — System76's Rust-based desktop on all graphical machines
- 🎨 **matugen theming** — Wallpaper-driven color pipeline; terminal, editor, and desktop all update automatically when the wallpaper rotates
- 🗄️ **BTRFS everywhere** — `@`, `@home`, `@nix`, `@log`, `@cache`, `@snapshots`, `@swap` subvolumes on every host
- 📸 **Automatic snapshots** — Snapper takes hourly/daily/weekly snapshots of `/` and `/home`
- 🔐 **ragenix secrets** — SSH keys, WireGuard config, and service passwords encrypted in the repo; no plaintext ever in version control
- 🦊 **Firefox enterprise policies** — uBlock Origin, search engine, and privacy settings locked in declaratively
- 🎮 **Gaming** — Steam, MangoHud, GameMode, ProtonPlus, Lutris on all gaming machines
- 🛡️ **VPN-scoped qBittorrent** — WireGuard network namespace killswitch on Radxa-X4; IP leaks are structurally impossible
- 🎬 **Media server** — Plex, Sonarr, Radarr, Prowlarr, Immich, FreshRSS on dedicated hardware
- 📁 **Family Samba shares** — Network shares auto-mounted on all desktops via CIFS + agenix credentials
- 🌐 **Tailscale mesh** — All machines reachable by hostname from anywhere
- 🐚 **Zsh + Starship + Kitty** — Terminal environment with NixOS management abbreviations

---

## 🖥️ Hosts

| Host | User | Role | LUKS |
|------|------|------|------|
| **ThinkPad** | linuxury | Laptop | ✅ |
| **Ryzen5900x** | linuxury | Desktop | ❌ |
| **Ryzen5800x** | babylinux | Desktop | ❌ |
| **Asus-A15** | babylinux | Laptop | ✅ |
| **Alex-Desktop** | alex | Kid's desktop | ❌ |
| **Alex-Laptop** | alex | Kid's laptop | ❌ |
| **Media-Server** | — | Plex · Arr stack · Immich · FreshRSS | ❌ |
| **Radxa-X4** | — | Torrent (Mullvad VPN killswitch) | ❌ |
| **MinisForum** | — | Game servers (Minecraft · Hytale) | ❌ |

---

## 📁 Structure

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
│   ├── base/                    # Shared system modules (common, snapper, firefox, etc.)
│   ├── desktop-environments/    # COSMIC DE + Flatpak
│   ├── hardware/                # GPU driver logic (AMD / Nvidia / Intel)
│   └── services/                # Samba, VPN-qBittorrent, wallpaper-slideshow
├── users/                       # Home Manager configs
│   ├── linuxury/home.nix
│   ├── babylinux/home.nix
│   └── alex/home.nix
├── dotfiles/                    # Config files symlinked by Home Manager
│   ├── nvim/                    # Neovim — full IDE config
│   ├── ghostty/                 # Ghostty terminal config + shaders
│   ├── zsh/                     # Shared zsh init
│   └── fastfetch/               # Fastfetch system info config
├── secrets/                     # age-encrypted secrets (safe to commit)
│   ├── secrets.nix              # Access control — who can read what
│   └── *.age                    # Encrypted secret files
├── assets/                      # Wallpapers, avatars, SteamGridDB art
└── docs/                        # Documentation (see below)
```

---

## 📚 Documentation

| # | File | What it covers |
|---|------|----------------|
| 01 | [Installation Guide](docs/01-installation.md) | ISO → partitioning → LUKS/plain → BTRFS → flake install |
| 02 | [First Boot](docs/02-first-boot.md) | Tailscale, SSH keys, secrets registration, assets, per-host steps |
| 03 | [Flake & Module Reference](docs/03-flake-guide.md) | Config structure, mkHost, adding hosts and packages |
| 04 | [Secrets Management](docs/04-secrets.md) | ragenix workflow, secrets.nix, creating and re-keying secrets |
| 05 | [Maintenance](docs/05-maintenance.md) | Rebuilds, updates, snapshots, rollback, garbage collection |
| 06 | [Server Management](docs/06-servers.md) | Media-Server, Radxa-X4, MinisForum — services and operations |
| 07 | [Applications](docs/07-applications.md) | Neovim IDE, Kitty, Ghostty, Zsh, Helix, Zed, and more |
| 08 | [Gaming](docs/08-gaming.md) | Proton-GE, Steam, MangoHud, launch options |
| 09 | [Theming](docs/09-theming.md) | matugen pipeline, wallpaper rotation, color sync |
| 10 | [Desktop Environment](docs/10-de-wm.md) | COSMIC DE config, sidebar favorites, Flatpak |
| 11 | [Troubleshooting](docs/11-troubleshooting.md) | Common failures and fixes across all areas |

---

## 📝 License

MIT — feel free to use and adapt for your own systems.
