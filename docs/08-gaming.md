# 🎮 Gaming

Steam, Proton-GE, MangoHud, and game-related setup for linuxury and babylinux's machines. Also covers Minecraft for Alex and the Hytale launcher for babylinux and alex.

---

## 📋 Contents

- [Gaming Machines](#gaming-machines)
- [Steam](#steam)
- [Proton-GE](#proton-ge)
- [Steam Launch Options](#steam-launch-options)
- [MangoHud](#mangohud)
- [SteamGridDB Artwork](#steamgriddb-artwork)
- [Asus-A15: Hybrid GPU Details](#asus-a15-hybrid-gpu-details)
- [Alex's Machines — Minecraft (Prism Launcher)](#alexs-machines--minecraft-prism-launcher)
- [Hytale (babylinux and alex)](#hytale-babylinux-and-alex)
- [Common Gaming Fixes](#common-gaming-fixes)

---

## 🖥️ Gaming Machines

[↑ Back to Contents](#-contents)

| Host | User | GPU | Notes |
|------|------|-----|-------|
| ThinkPad | linuxury | AMD integrated | Light gaming only |
| Ryzen5900x | linuxury | AMD | Primary gaming desktop |
| Ryzen5800x | babylinux | AMD | Desktop |
| Asus-A15 | babylinux | AMD + Nvidia hybrid | Laptop — PRIME config required |

Alex's machines don't have Steam. He uses Prism Launcher for Minecraft only.

---

## 🚂 Steam

[↑ Back to Contents](#-contents)

Steam is installed as part of the gaming config. On first launch:

1. Log in with your Steam account
2. Enable Steam Play for all titles: **Steam → Settings → Compatibility → Enable Steam Play for all other titles**
3. Select **Proton** as the compatibility tool (you'll set Proton-GE as the default after installing it via ProtonPlus)

---

## ⚙️ Proton-GE

[↑ Back to Contents](#-contents)

Proton-GE is a community-maintained fork of Proton with better game compatibility than Steam's built-in Proton — especially for newer titles, games with video/cutscene issues, and some anti-cheat titles. It receives updates faster than Valve's official builds.

### Installing Proton-GE

1. Open **ProtonPlus** (installed on all gaming machines via `home.packages`)
2. Select **GE-Proton** from the list
3. Click **Install** on the latest version (e.g. `GE-Proton9-XX`)

ProtonPlus installs to `~/.local/share/Steam/compatibilitytools.d/`. Steam detects it automatically — no restart needed.

### Setting Proton-GE as the default

**Steam → Settings → Compatibility → Steam Play → select `GE-ProtonX-XX`**

### Per-game Proton override

Right-click a game → **Properties → Compatibility → Force use of a specific compatibility tool** → select `GE-ProtonX-XX`.

Use this when a specific game works better with one version but you don't want to change the global default.

---

## 🚀 Steam Launch Options

[↑ Back to Contents](#-contents)

Set launch options per game: right-click → **Properties → General → Launch Options**.

> 💡 `%command%` is required at the end of every launch option. It is the placeholder for the actual game executable. Everything before it is environment variables that Proton reads at launch.

### Performance overlays and GameMode

| Launch option | What it does |
|---------------|-------------|
| `MANGOHUD=1 %command%` | Enable MangoHud overlay (FPS, frame time, GPU/CPU, temps) |
| `gamemoderun %command%` | Enable GameMode (CPU governor boost, process priority) |
| `MANGOHUD=1 gamemoderun %command%` | Both together — the most common combination |

### Wayland and display

| Launch option | What it does |
|---------------|-------------|
| `PROTON_USE_WAYLAND=1 %command%` | Enable native Wayland driver instead of XWayland |
| `PROTON_ENABLE_HDR=1 %command%` | Enable HDR output (does not check if your monitor supports it) |

### Upscaling and frame generation

| Launch option | What it does |
|---------------|-------------|
| `PROTON_FSR4_UPGRADE=1 %command%` | Automatically upgrade games using FSR 3.1 to FSR 4 |
| `WINE_FULLSCREEN_FSR=1 %command%` | Enable AMD FSR 1 upscaling (any GPU, older fallback) |

> 💡 FSR4 requires a recent Mesa version and an RDNA GPU. Proton-GE downloads the required `amdxcffx64` automatically when this flag is set.

### Input

| Launch option | What it does |
|---------------|-------------|
| `PROTON_USE_SDL=1 %command%` | Use SDL input instead of HIDRAW/Steam Input |
| `PROTON_PREFER_SDL=1 %command%` | Prefer SDL input (less aggressive than USE_SDL) |
| `WAYLANDDRV_RAWINPUT=0 %command%` | Disable raw input if mouse feels too sensitive on Wayland |

### Media / video playback

| Launch option | What it does |
|---------------|-------------|
| `PROTON_ENABLE_MEDIACONV=1 %command%` | Enable media converter for cutscenes and video playback |

### Debugging and sync

| Launch option | What it does |
|---------------|-------------|
| `PROTON_LOG=1 %command%` | Write a Proton debug log to `~/.steam/steam/logs/` |
| `PROTON_NO_ESYNC=1 %command%` | Disable esync (try if game crashes or has sync errors) |
| `PROTON_NO_FSYNC=1 %command%` | Disable fsync (try alongside or instead of esync fix) |
| `PROTON_NO_NTSYNC=1 %command%` | Disable NTsync (try if the above don't help) |
| `PROTON_USE_WINED3D=1 %command%` | Use OpenGL instead of DXVK for DX9-11 games |

### Combining multiple options

Options stack — put them all before `%command%`:

```
MANGOHUD=1 gamemoderun PROTON_USE_WAYLAND=1 PROTON_FSR4_UPGRADE=1 %command%
```

Or use `PROTON_ADD_CONFIG` to combine Proton flags more cleanly:

```
PROTON_ADD_CONFIG=wayland,fsr4 gamemoderun MANGOHUD=1 %command%
```

Available `PROTON_ADD_CONFIG` values: `sdlinput`, `fsr4`, `fsr4rdna3`, `hdr`, `wayland`, `wow64`, `nontsync`

### Asus-A15: force Nvidia dGPU

By default, games run on the AMD iGPU. Add these launch options to force the Nvidia discrete GPU instead:

```
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia MANGOHUD=1 gamemoderun %command%
```

---

## 📊 MangoHud

[↑ Back to Contents](#-contents)

MangoHud is an in-game overlay showing FPS, frame time, GPU/CPU usage, and temperatures. It works with Vulkan and OpenGL games.

**Config file:** `~/.config/MangoHud/MangoHud.conf`

Example config showing common metrics:

```ini
fps
frame_timing
gpu_stats
cpu_stats
ram
```

**Toggle overlay in-game:** `Right Shift + F12` (default keybind — configurable in `MangoHud.conf`)

---

## 🎨 SteamGridDB Artwork

[↑ Back to Contents](#-contents)

Custom box art and banners for your Steam library are stored in `assets/SteamGridDB/` and symlinked to `~/Pictures/SteamGridDB/` by Home Manager.

To apply in Steam:

1. Right-click a game → **Manage → Set Custom Artwork**
2. Navigate to `~/Pictures/SteamGridDB/` and select the image

---

## 🎯 Asus-A15: Hybrid GPU Details

[↑ Back to Contents](#-contents)

The Asus A15 has both an AMD iGPU and an Nvidia dGPU. PRIME offload routes specific apps to the Nvidia GPU on demand while the AMD iGPU handles everything else (better battery life).

The PCI bus IDs in `hosts/Asus-A15/default.nix` must match this specific machine. Find them:

```bash
lspci | grep -E "VGA|3D"
# Example output:
# 05:00.0 VGA compatible controller: AMD ...  → PCI:5:0:0
# 01:00.0 3D controller: NVIDIA ...           → PCI:1:0:0
```

Convert `05:00.0` → `PCI:5:0:0` (decimal, colon-separated) and update `hosts/Asus-A15/default.nix`:

```nix
hardware.nvidia.prime = {
  amdgpuBusId = "PCI:5:0:0";   # your actual value
  nvidiaBusId  = "PCI:1:0:0";  # your actual value
};
```

Rebuild after editing:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#Asus-A15
```

---

## 🧊 Alex's Machines — Minecraft (Prism Launcher)

[↑ Back to Contents](#-contents)

Alex uses **Prism Launcher** for Minecraft Java Edition. Prism manages multiple Minecraft versions and mod packs independently, which is better than the official launcher for running different versions.

**First launch:**

1. Open Prism Launcher
2. Log in with Alex's Mojang account (he has his own — separate from yours)
3. Create an instance with the desired Minecraft version

**Mods and assets:** `~/assets/Minecraft/` is available for mod packs or resource packs — it's cloned from the assets repo.

Alex's machines don't have Steam. Flatpak remotes are reset declaratively after every rebuild so COSMIC Store is intentionally empty — only the Hytale flatpak is allowed.

---

## 🎮 Hytale (babylinux and alex)

[↑ Back to Contents](#-contents)

The Hytale launcher installs automatically on first login via a one-shot systemd user service. It reads the pre-downloaded flatpak bundle at:

```
~/Documents/assets/flatpaks/hytale-launcher-latest.flatpak
```

The assets repo must be cloned first — see [02-first-boot.md](02-first-boot.md).

The service only runs if the app is not already installed:

```
ConditionPathExists = !%h/.local/share/flatpak/app/com.hytale.Hytale
```

Check install status:

```bash
systemctl --user status hytale-flatpak-install        # check if the service ran
flatpak list --user | grep Hytale                      # confirm the app is installed
```

---

## 🔧 Common Gaming Fixes

[↑ Back to Contents](#-contents)

### Game won't launch or crashes immediately

1. Switch to Proton-GE if using default Proton (or switch back to default if already using GE)
2. Add `PROTON_LOG=1 %command%` to launch options, then check `~/.steam/steam/logs/`
3. Right-click game → **Manage → Browse local files** — look for crash logs in the game directory

### Poor performance on Asus-A15

Verify the Nvidia GPU is active. If `nvidia-smi` doesn't show the game process, add the PRIME launch options:

```bash
nvidia-smi   # the game process should appear here if running on the dGPU
```

### MangoHud not showing

- Confirm `MANGOHUD=1` is in launch options (not `mangohud=1` — it's case-sensitive)
- Run `which mangohud` to confirm the binary is installed
- Some anti-cheat games block overlay injection — MangoHud won't work for those

### Steam library on external drive

**Steam → Settings → Storage → Add Drive** → select the mount point (e.g. `/mnt/Media-Server`).
