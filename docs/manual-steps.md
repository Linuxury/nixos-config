# Manual Steps

These are the things that cannot be declared in Nix and must be done by hand
after the first `nixos-rebuild switch` on each machine. Work through the
**All Machines** section first, then the section for the specific host.

---

## All Machines

### Set user passwords
```bash
sudo passwd linuxury    # or babylinux / alex depending on the host
```
Never put passwords in this repo.

### Clone the assets repo
Wallpapers, the Hytale flatpak, and SteamGridDB artwork live in a separate
assets repo (not committed here because of size). Clone it as the correct user:
```bash
# On linuxury's machines
git clone <assets-repo-url> ~/assets

# On babylinux's machines
sudo -u babylinux git clone <assets-repo-url> /home/babylinux/assets

# On alex's machines
sudo -u alex git clone <assets-repo-url> /home/alex/assets
```
Required contents:
- `assets/Wallpapers/4k/`          — linuxury and babylinux machines
- `assets/Wallpapers/3440x1440/`   — Ryzen5900x only
- `assets/Wallpapers/PikaOS/`      — Alex's machines
- `assets/flatpaks/hytale-launcher-latest.flatpak` — babylinux and alex
- `assets/SteamGridDB/`            — gaming machines (optional)

### Clone matugen templates
The wallpaper slideshow uses matugen to theme the desktop. Templates come
from the matugen-themes community repo:
```bash
git clone https://github.com/InioX/matugen-themes \
  ~/nixos-config/dotfiles/matugen/templates
```
Do this once in the repo — Home Manager symlinks it into place for all users.

### Tailscale
Run on every machine you want on the tailnet:
```bash
sudo tailscale up
```
Log in with your Tailscale account when prompted.

---

## ThinkPad (linuxury)

### Fingerprint enrollment
The fingerprint sensor is configured — enroll a finger after first boot:
```bash
fprintd-enroll linuxury
```
You may need to run `fprintd-verify` afterwards to confirm it works.

---

## Ryzen5900x (linuxury)

No extra manual steps beyond the All Machines section.

---

## Ryzen5800x (babylinux)

### VPN Unlimited WireGuard config
The WireGuard config is managed by agenix — it is decrypted automatically at
activation to `/etc/wireguard/vpnunlimited.conf`. You just need to create the
secret once from your admin machine and commit it:

```bash
# On your admin machine (in the nixos-config repo)
nix run nixpkgs#agenix -- -e secrets/wireguard-vpnunlimited.age
# Paste the full wg-quick config exported from VPN Unlimited, save, close
```

To export the config from VPN Unlimited:
1. Open the VPN Unlimited app on any device
2. Go to **Manage → WireGuard** (or Settings → WireGuard)
3. Select a server and export the config as a `.conf` file
4. Paste the contents when the editor opens above

After the secret is committed and the machine rebuilds, start the services:
```bash
sudo systemctl start vpn-qbt-netns
sudo systemctl start qbittorrent-vpn
```

Open the qBittorrent web UI at **http://10.200.200.2:8080**
Default login: `admin` / `adminadmin` — **change this immediately** in
Settings → Web UI → Authentication.

Configure download paths in qBittorrent Settings → Downloads:
- Default save path: `/home/babylinux/Downloads/torrents/complete`
- Incomplete: `/home/babylinux/Downloads/torrents/incomplete`

---

## Asus-A15 (babylinux)

### VPN Unlimited WireGuard config
Same agenix-managed secret as Ryzen5800x — the same `.age` file is used for
both machines (both are listed as recipients in `secrets/secrets.nix`). If you
already created the secret for Ryzen5800x, no further action is needed here.

### PRIME PCI bus IDs
The Nvidia hybrid graphics config has placeholder PCI IDs. Find the real ones:
```bash
lspci | grep -E "VGA|3D"
# Example output:
# 05:00.0 VGA compatible controller: Advanced Micro Devices ... (AMD iGPU)
# 01:00.0 3D controller: NVIDIA Corporation TU116M ... (Nvidia dGPU)
```
Convert `05:00.0` → `PCI:5:0:0` and fill in
[hosts/Asus-A15/default.nix](../hosts/Asus-A15/default.nix):
```nix
hardware.nvidia.prime = {
  amdgpuBusId = "PCI:5:0:0";  # replace with your actual value
  nvidiaBusId = "PCI:1:0:0";  # replace with your actual value
};
```
Then rebuild: `sudo nixos-rebuild switch --flake .#Asus-A15`

### Battery charge limit
Set the charge threshold to protect long-term battery health:
```bash
asusctl -c 80
```
This is persistent across reboots.

---

## Alex-Desktop and Alex-Laptop (alex)

### Flatpak remotes
Flatpak remotes are wiped declaratively after every rebuild so the COSMIC
app store shows nothing. No action needed — this is automatic.

### Minecraft account
After Prism Launcher opens for the first time, log in with Alex's Mojang
account. He has his own account separate from yours.

### Hytale
The Hytale flatpak installs automatically on first login from:
`~/assets/flatpaks/hytale-launcher-latest.flatpak`
(Requires the assets repo to be cloned first — see All Machines section.)

---

## MinisForum (server)

### Samba users
All three family users exist but Samba passwords must be set separately from
Linux passwords. Run this after first boot:
```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
sudo smbpasswd -a alex
```
Each command prompts for the new Samba password twice.

> MinisForum's Samba shares are TBD — add them to
> [hosts/MinisForum/default.nix](../hosts/MinisForum/default.nix) when its
> role is finalized. Import `modules/services/samba.nix` there too.

---

## Radxa-X4 (server)

### FreshRSS admin password
The password is managed by agenix — create the secret once from your admin
machine:
```bash
nix run nixpkgs#agenix -- -e secrets/freshrss-admin-password.age
# Type the password, save, close
```

After the machine rebuilds, open **http://Radxa-X4:8080** and complete the
setup wizard. The admin account (`linuxury`) is created automatically from the
agenix-decrypted password file.

**FreshRSS GReader API** — for mobile apps (Reeder, FeedMe, Fluent Reader):
- Enable it in FreshRSS → Settings → Authentication → Allow API access
- API endpoint: `http://Radxa-X4:8080/api/greader.php`

---

## Media-Server (server)

### Samba passwords
Same as MinisForum — set after first boot:
```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
sudo smbpasswd -a alex
```

Shares available after setup:
| Share | Path | Access |
|-------|------|--------|
| `\\Media-Server\media` | `/data/media` | All read, linuxury write |
| `\\Media-Server\shared` | `/data/shared` | All read/write |
| `\\Media-Server\downloads` | `/data/downloads` | linuxury + babylinux |

### Plex setup
1. Open http://Media-Server:32400/web
2. Sign in with your Plex account
3. Add libraries pointing at `/data/media/movies`, `/data/media/tv`, etc.
4. Enable **Hardware-Accelerated Transcoding** (requires Plex Pass):
   Settings → Transcoder → Use hardware acceleration when available
5. Verify VAAPI is working: `vainfo` should show the RX 480 as a decoder

### Hard drive labels
The media drives must be labeled `disk1` and `disk2` for the mergerfs mount
to work. Label them during NixOS installation:
```bash
# For ext4:
sudo e2label /dev/sdX disk1
sudo e2label /dev/sdY disk2
```

### ProtonPlus (gaming machines: ThinkPad, Ryzen5900x, Ryzen5800x, Asus-A15)
After Steam is installed and launched for the first time, open ProtonPlus
and install the latest **Proton-GE** version. This improves game compatibility
beyond what Steam's default Proton offers.
