# First Boot

Everything that needs to happen after `nixos-install` completes and the machine boots for the first time. Work through the **All Machines** section in order, then find your specific host below for any extra steps.

SSH in from your admin machine for most of this — it is much easier than typing on the target:

```bash
ssh linuxury@<hostname-or-ip>
```

---

## Contents

- [All Machines](#all-machines)
  - [1 — Set user passwords](#1--set-user-passwords)
  - [2 — Connect to Tailscale](#2--connect-to-tailscale)
  - [3 — Generate an SSH key (admin machines only)](#3--generate-an-ssh-key-admin-machines-only)
  - [4 — Register the machine in secrets.nix and re-key](#4--register-the-machine-in-secretsnix-and-re-key)
  - [5 — Rebuild to apply secrets](#5--rebuild-to-apply-secrets)
  - [6 — Clone assets](#6--clone-assets)
- [ThinkPad (linuxury)](#thinkpad-linuxury)
- [Ryzen5900x (linuxury)](#ryzen5900x-linuxury)
- [Ryzen5800x and Asus-A15 (babylinux)](#ryzen5800x-and-asus-a15-babylinux)
- [Alex-Desktop and Alex-Laptop (alex)](#alex-desktop-and-alex-laptop-alex)
- [Media-Server](#media-server)
- [Radxa-X4](#radxa-x4)
- [MinisForum](#minisforum)
- [Checklist](#checklist)

---

## All Machines

Work through each step in order. Every machine goes through all six steps — even servers.

---

### 1 — Set user passwords

NixOS does not set passwords from the config for security reasons. Set them manually after first boot.

For the primary user on this machine:

```bash
sudo passwd linuxury    # on linuxury's machines (ThinkPad, Ryzen5900x)
sudo passwd babylinux  # on babylinux's machines (Ryzen5800x, Asus-A15)
sudo passwd alex        # on alex's machines (Alex-Desktop, Alex-Laptop)
```

> Never put passwords in the repo. Always set them by hand.

---

### 2 — Connect to Tailscale

Tailscale is a VPN that makes every machine reachable by hostname from anywhere on the tailnet. Once connected, you can SSH to any machine by name instead of by IP — including across networks.

```bash
sudo tailscale up   # opens a browser or prints a URL — log in with your Tailscale account
```

After authenticating, verify the machine appears and has an IP:

```bash
tailscale status   # should show this machine and any others already on the tailnet
```

---

### 3 — Generate an SSH key (admin machines only)

> Skip this step for servers (Media-Server, Radxa-X4, MinisForum) — they do not need a personal SSH key.

On linuxury's machines (ThinkPad, Ryzen5900x), generate a key pair. Accept the default path (`~/.ssh/id_ed25519`) and set a passphrase when prompted:

```bash
ssh-keygen -t ed25519 -C "linuxurypr@gmail.com"
```

Print the public key, then add it to GitHub at **Settings → SSH and GPG keys → New SSH key**:

```bash
cat ~/.ssh/id_ed25519.pub   # copy this and paste it into GitHub
```

Verify GitHub accepts the key:

```bash
ssh -T git@github.com   # expected: "Hi Linuxury! You've successfully authenticated..."
```

The nixos-config was cloned via HTTPS during installation. Switch its remote to SSH now that your key is registered:

```bash
cd ~/nixos-config
git remote set-url origin git@github.com:linuxury/nixos-config.git
```

---

### 4 — Register the machine in secrets.nix and re-key

Every machine needs its SSH host key listed in `secrets/secrets.nix` so agenix can decrypt secrets on it at boot. Agenix encrypts each secret file to a specific list of SSH public keys — a machine not on that list gets an encrypted blob it cannot open.

Get the new machine's host key (run this on the new machine):

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub
```

**On your admin machine**, open `secrets/secrets.nix` and add the key:

```nix
let
  new-machine-host = "ssh-ed25519 AAAA...";   # paste the key here
in
{
  "smb-credentials.age".publicKeys = [
    # ... existing keys ...
    new-machine-host   # add to every secret this machine needs
  ];
}
```

Re-key all secrets so the new machine is added as a recipient. This must run from the `secrets/` directory using ragenix (not `agenix`):

```bash
cd ~/nixos-config/secrets
nix run nixpkgs#ragenix -- -r   # re-encrypt all .age files with the updated recipient list
```

Commit and push the updated secrets:

```bash
cd ~/nixos-config
git add secrets/
git commit -m "add host key for <HostName>"
git push
```

> The tool is **ragenix**, not agenix. Use `nix run nixpkgs#ragenix` — not `nix run github:ryantm/agenix`. It must run from the `secrets/` directory.

---

### 5 — Rebuild to apply secrets

Pull the updated secrets on the new machine and rebuild so agenix can now decrypt:

```bash
cd ~/nixos-config
git pull
sudo nixos-rebuild switch --flake ~/nixos-config#<HostName>   # replace with the exact host name from flake.nix
```

Or use the `nr` abbreviation if it's already set up:

```bash
nr   # expands to: sudo nixos-rebuild switch --flake ~/nixos-config#$(hostname)
```

---

### 6 — Clone assets

Wallpapers and game assets live in a separate private repo because of file size. Clone it to the correct location for each user:

```bash
# On linuxury's machines — Home Manager symlinks from ~/nixos-config/assets
# (already present — nixos-config contains the assets subdirectory)

# On babylinux's machines
sudo -u babylinux git clone <assets-repo-url> /home/babylinux/assets

# On alex's machines
sudo -u alex git clone <assets-repo-url> /home/alex/assets
```

Required wallpaper directories per user:

| Path | Who needs it |
|------|-------------|
| `assets/Wallpapers/4k/` | linuxury (ThinkPad), babylinux, alex |
| `assets/Wallpapers/3440x1440/` | linuxury (Ryzen5900x only) |
| `assets/Wallpapers/PikaOS/` | alex's machines |
| `assets/flatpaks/hytale-launcher-latest.flatpak` | babylinux, alex |

> The matugen template repo is auto-cloned by Home Manager activation (`home.activation.matugenTemplates`) if it's missing — you do not need to clone it manually.

---

## ThinkPad (linuxury)

### Fingerprint enrollment

The ThinkPad has a fingerprint sensor, and the driver is configured in NixOS. Enroll a finger after first boot so sudo and the login screen can use it:

```bash
fprintd-enroll linuxury   # follow the prompts — swipe the finger several times
fprintd-verify linuxury   # confirm it reads correctly
```

---

## Ryzen5900x (linuxury)

No extra steps beyond the All Machines section.

---

## Ryzen5800x and Asus-A15 (babylinux)

### PRIME GPU bus IDs (Asus-A15 only)

The Asus A15 has hybrid AMD + Nvidia graphics (AMD iGPU + Nvidia dGPU). PRIME offload lets you route specific apps to the Nvidia GPU. The PCI bus IDs in the config are placeholders — find the real ones on this machine:

```bash
lspci | grep -E "VGA|3D"
# Example:
# 05:00.0 VGA compatible controller: AMD ...    → PCI:5:0:0
# 01:00.0 3D controller: NVIDIA ...             → PCI:1:0:0
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

### Battery charge limit (Asus-A15 only)

Limit charging to 80% to protect long-term battery health. This persists across reboots:

```bash
asusctl -c 80
```

---

## Alex-Desktop and Alex-Laptop (alex)

### Minecraft account

After Prism Launcher opens for the first time, log in with Alex's Mojang account. He has his own account — separate from yours.

### Hytale

The Hytale flatpak installs automatically on first login from the local bundle at `~/Documents/assets/flatpaks/hytale-launcher-latest.flatpak`. Requires the assets repo to be cloned first — see [Step 6](#6--clone-assets) above.

---

## Media-Server

### Samba passwords

Samba maintains its own password database separate from Linux user passwords. Set them manually after first boot:

```bash
sudo smbpasswd -a linuxury    # prompts for the Samba password twice
sudo smbpasswd -a babylinux
sudo smbpasswd -a alex
```

### Hard drive labels

If this is a fresh install with new data drives, label them so mergerfs can find them by label. Replace `/dev/sdX` and `/dev/sdY` with your actual drive devices (use `lsblk` to identify them):

```bash
sudo e2label /dev/sdX disk1   # label the first data drive
sudo e2label /dev/sdY disk2   # label the second data drive
```

### Plex initial setup

1. Open `http://Media-Server:32400/web` in a browser
2. Sign in with your Plex account
3. Add libraries pointing at `/data/media/movies`, `/data/media/tv`, etc.
4. Enable hardware transcoding: **Settings → Transcoder → Use hardware acceleration when available**

---

## Radxa-X4

### VPN verification

After first boot, verify the Mullvad WireGuard VPN is up before qBittorrent runs:

```bash
sudo wg show                                                  # should show the wireguard interface with a handshake
sudo ip netns exec qbt-vpn curl https://am.i.mullvad.net/ip  # should return a Mullvad exit IP, not your home IP
```

### qBittorrent web UI

After the VPN services start:

- Web UI: `http://10.200.200.2:8080` (inside the VPN network namespace — only reachable via Tailscale or SSH tunnel)
- Default login: `admin` / `adminadmin`

> Change the default password immediately. **Settings → Web UI → Authentication**.

Configure download paths:

- Complete: `/data/torrents/complete`
- Incomplete: `/data/torrents/incomplete`

---

## MinisForum

### Samba passwords

Samba passwords are separate from Linux passwords and must be set after first boot:

```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
sudo smbpasswd -a alex
```

---

## Checklist

Use this to confirm nothing was missed before considering the setup complete.

- [ ] User password set (`sudo passwd <user>`)
- [ ] Tailscale connected (`tailscale status`)
- [ ] SSH key generated and added to GitHub (admin machines only)
- [ ] Machine registered in `secrets/secrets.nix`
- [ ] Secrets re-keyed (`age-rekey` from the `secrets/` directory)
- [ ] Config pulled and rebuilt (`git pull && nr`)
- [ ] Assets cloned to the correct location
- [ ] Host-specific steps done (see sections above)
