# 🧩 Flake & Module Reference

This guide explains how the configuration is structured, how to read and edit it, and how to add new hosts, users, or packages. A "flake" is NixOS's way of pinning all dependencies to exact versions and defining what each machine should look like — think of it as the entry point that ties everything together.

---

## 📋 Contents

- [Directory Layout](#directory-layout)
- [How a Rebuild Works](#how-a-rebuild-works)
- [How flake.nix Works](#how-flakenix-works)
  - [Inputs — where packages come from](#inputs--where-packages-come-from)
  - [The mkHost helper](#the-mkhost-helper)
- [Host Config Structure](#host-config-structure)
- [Home Manager Config Structure](#home-manager-config-structure)
- [Adding a New Host](#adding-a-new-host)
- [Adding a Package](#adding-a-package)
- [Updating Dependencies](#updating-dependencies)
- [Evaluating Without Rebuilding](#evaluating-without-rebuilding)
- [Common Patterns](#common-patterns)

---

## 📁 Directory Layout

[↑ Back to Contents](#-contents)

```
nixos-config/
├── flake.nix                  ← Entry point — host definitions live here
├── flake.lock                 ← Locked dependency versions (never edit manually)
├── secrets/
│   ├── secrets.nix            ← Who can decrypt which secrets
│   └── *.age                  ← Encrypted secret files (safe to commit)
├── hosts/
│   ├── ThinkPad/
│   │   ├── default.nix        ← System-level config for this host
│   │   └── hardware-configuration.nix  ← Auto-generated hardware config
│   ├── Ryzen5900x/
│   ├── Ryzen5800x/
│   ├── Asus-A15/
│   ├── Alex-Desktop/
│   ├── Alex-Laptop/
│   ├── Media-Server/
│   ├── MinisForum/
│   └── Radxa-X4/
├── users/
│   ├── linuxury/home.nix      ← Home Manager config for linuxury
│   ├── babylinux/home.nix     ← Home Manager config for babylinux
│   └── alex/home.nix          ← Home Manager config for alex
├── modules/
│   ├── base/
│   │   ├── graphical-base.nix ← Packages shared by all graphical machines
│   │   ├── server-shell.nix   ← Zsh + tools for headless servers
│   │   └── *.nix              ← Other shared system modules
│   ├── desktop-environments/
│   │   └── cosmic.nix         ← COSMIC DE + Flatpak setup
│   ├── hardware/
│   │   └── drivers.nix        ← GPU driver config
│   └── services/
│       ├── wallpaper-slideshow.nix  ← Wallpaper + matugen theming
│       └── *.nix              ← Other service modules
├── dotfiles/
│   ├── ghostty/config         ← Ghostty terminal config (shared, symlinked)
│   ├── zsh/zshrc              ← Shared zsh init file
│   └── nvim/                  ← Neovim config (symlinked to ~/.config/nvim)
├── assets/
│   ├── Wallpapers/            ← linuxury's wallpapers (from this repo)
│   ├── Avatar/                ← linuxury's profile picture
│   └── Minecraft/             ← Minecraft artwork
└── docs/                      ← This documentation
```

---

## 🔄 How a Rebuild Works

[↑ Back to Contents](#-contents)

When you run:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#ThinkPad
```

Nix does this in order:

1. Reads `flake.nix` and finds the `ThinkPad` entry
2. Loads `hosts/ThinkPad/default.nix` (system-level config)
3. Loads `users/linuxury/home.nix` (Home Manager config)
4. Evaluates all imported modules recursively
5. Builds any packages or configs that changed since the last build
6. Activates the new config: services restart, symlinks update, dotfiles regenerate

Nothing is applied until you run the rebuild. Editing a file alone changes nothing on the live system.

> 💡 The `nr` shell abbreviation expands to `sudo nixos-rebuild switch --flake ~/nixos-config#$(hostname)` — use it instead of typing the full command.

---

## 🏗️ How flake.nix Works

[↑ Back to Contents](#-contents)

The flake has two parts: **inputs** (where things come from) and **outputs** (what this flake defines).

### Inputs — where packages come from

```nix
inputs = {
  nixpkgs.url     = "github:nixos/nixpkgs/nixos-unstable";  # all packages
  home-manager    = { ... };   # per-user config management (Home Manager)
  nixos-hardware  = { ... };   # hardware profiles (ThinkPad tweaks, etc.)
  agenix          = { ... };   # secret management (the ragenix CLI wraps this)
};
```

These are "locked" in `flake.lock` — the exact git commit for each input is pinned so your system is fully reproducible. Update with `nix flake update`.

### The mkHost helper

Instead of repeating boilerplate for every host, a single helper function builds any host from a short definition:

```nix
mkHost = { hostname, hostConfig, user, userConfig ? null, wallpaperDir ? "4k", extraModules ? [] }:
  nixpkgs.lib.nixosSystem { ... };
```

Each host in `nixosConfigurations` calls `mkHost` with its specific values:

```nix
ThinkPad = mkHost {
  hostname     = "ThinkPad";
  hostConfig   = ./hosts/ThinkPad/default.nix;
  user         = "linuxury";
  userConfig   = ./users/linuxury/home.nix;
  wallpaperDir = "4k";
  extraModules = [ nixos-hardware.nixosModules.lenovo-thinkpad ];
};
```

`wallpaperDir` tells Home Manager which wallpaper subfolder to symlink into `~/Pictures/Wallpapers`. Servers omit `userConfig` entirely — Home Manager does not run for headless hosts.

---

## 📋 Host Config Structure

[↑ Back to Contents](#-contents)

Every host has a `hosts/<HostName>/default.nix` file with system-level configuration. A typical graphical host looks like:

```nix
{ inputs, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/base/graphical-base.nix
    ../../modules/desktop-environments/cosmic.nix
    ../../modules/hardware/drivers.nix
    # ... more modules as needed
  ];

  networking.hostName = "ThinkPad";

  boot.loader.systemd-boot.enable = true;

  users.users.linuxury = {
    isNormalUser  = true;
    extraGroups   = [ "wheel" "networkmanager" "video" ];
  };

  # Secrets — decrypted by agenix at activation and placed in /run/agenix/
  age.secrets.smb-credentials.file = ../../secrets/smb-credentials.age;

  # Filesystem mounts
  fileSystems."/mnt/Media-Server" = { ... };
}
```

---

## 👤 Home Manager Config Structure

[↑ Back to Contents](#-contents)

Home Manager manages everything inside the user's home directory: packages, dotfiles, services, and app configuration. Each user's config lives at `users/<user>/home.nix`:

```nix
{ pkgs, lib, wallpaperDir, ... }:
{
  home.username     = "linuxury";
  home.homeDirectory = "/home/linuxury";

  # Packages installed for this user only (not system-wide)
  home.packages = with pkgs; [ yazi eza bat lazygit ... ];

  # Dotfiles symlinked declaratively from the repo
  home.file.".config/ghostty/config".source = ../../dotfiles/ghostty/config;

  # Programs managed by Home Manager (generates config files automatically)
  programs.zsh.enable = true;
  programs.git = { enable = true; userName = "Linuxury"; ... };

  # COSMIC config files (written directly to ~/.config/cosmic/...)
  home.file.".config/cosmic/...".text = "...";

  # Systemd user services
  systemd.user.services.wallpaper-color-sync = { ... };

  # wallpaperDir comes from flake.nix via extraSpecialArgs
  home.file."Pictures/Wallpapers".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/assets/Wallpapers/${wallpaperDir}";
}
```

---

## ➕ Adding a New Host

[↑ Back to Contents](#-contents)

Follow these steps in order. See [04-secrets.md](04-secrets.md) for the secrets step in detail.

1. **Create the host directory and config:**
   ```bash
   mkdir -p ~/nixos-config/hosts/NewHost
   # Copy an existing similar host as a starting point:
   cp ~/nixos-config/hosts/ThinkPad/default.nix ~/nixos-config/hosts/NewHost/default.nix
   ```
   Edit `default.nix`: update `networking.hostName`, imports, hardware options, and user assignments.

2. **Generate the hardware config** — boot the machine from the NixOS ISO and run the install (see [01-installation.md](01-installation.md)). The hardware config is generated as part of Step 11 in that guide.

3. **Register the host in `flake.nix`:**
   ```nix
   NewHost = mkHost {
     hostname   = "NewHost";
     hostConfig = ./hosts/NewHost/default.nix;
     user       = "linuxury";     # or babylinux / alex
     userConfig = ./users/linuxury/home.nix;
     wallpaperDir = "4k";
   };
   ```

4. **Add the host key to `secrets/secrets.nix`** and re-key — see [04-secrets.md](04-secrets.md).

5. **Install:**
   ```bash
   sudo nixos-install --flake ~/nixos-config#NewHost
   ```

---

## ➕ Adding a Package

[↑ Back to Contents](#-contents)

Where you add a package determines who gets it:

| Scope | Where to add it |
|-------|----------------|
| All graphical machines | `modules/base/graphical-base.nix` → `environment.systemPackages` |
| One specific host only | `hosts/<HostName>/default.nix` → `environment.systemPackages` |
| One specific user only | `users/<user>/home.nix` → `home.packages` |

Example for a user-level package in `users/linuxury/home.nix`:

```nix
home.packages = with pkgs; [
  yazi
  eza
  bat
  your-new-package   # ← add here
];
```

Then rebuild to apply: `nr`

---

## 🔁 Updating Dependencies

[↑ Back to Contents](#-contents)

`flake.lock` pins every input to an exact commit. Update all inputs at once, commit the new lock file, then rebuild to apply:

```bash
cd ~/nixos-config
nix flake update                                              # update all inputs; regenerates flake.lock
git add flake.lock
git commit -m "update flake inputs"
nr                                                            # rebuild and apply
```

To update a single input only (useful when one input has a known-good update):

```bash
nix flake update home-manager   # updates only home-manager, leaves others pinned
```

---

## 🐛 Evaluating Without Rebuilding

[↑ Back to Contents](#-contents)

Check for syntax and evaluation errors without doing a full build:

```bash
nix flake check   # evaluates all hosts and reports errors without building anything
```

Evaluate a specific config attribute to see what it resolves to:

```bash
nix eval .#nixosConfigurations.ThinkPad.config.networking.hostName
# outputs: "ThinkPad"
```

---

## 📝 Common Patterns

[↑ Back to Contents](#-contents)

### Conditional config (only on certain hosts)

Apply a setting only on specific machines without creating a separate module:

```nix
# In a shared module — applies the firewall rule only on Media-Server
networking.firewall.allowedTCPPorts =
  lib.mkIf (config.networking.hostName == "Media-Server") [ 32400 ];
```

### Per-host value via extraSpecialArgs

`wallpaperDir` is the main example. It's passed from `flake.nix` into Home Manager so each host uses a different wallpaper folder without needing separate `home.nix` files per host.

### mkOutOfStoreSymlink

Use this when a symlink target must be mutable or outside the Nix store. Regular `home.file` sources are read-only store paths — `mkOutOfStoreSymlink` creates a regular symlink to a path that can change:

```nix
home.file."Pictures/Wallpapers".source =
  config.lib.file.mkOutOfStoreSymlink "/home/linuxury/assets/Wallpapers/4k";
```

### Migration activations

When a file needs to move or be cleaned up before Home Manager creates a new symlink, use `entryBefore ["checkLinkTargets"]`:

```nix
home.activation.cleanupOldFile = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
  rm -f ~/.config/old-location
'';
```
