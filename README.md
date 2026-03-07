# 🏠 Linuxury NixOS Configuration

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue.svg?style=flat&logo=nixos&logoColor=white)](https://nixos.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A fully declarative, modular NixOS setup using flakes, designed for a 3-person family household across 6 desktop/laptop machines and 3 headless servers.

---

## ✨ Highlights

- 🎨 **COSMIC DE** — System76's Rust-based desktop, with wallpaper slideshow and matugen color theming
- 🗄️ **BTRFS everywhere** — `@`, `@home`, `@nix`, `@log`, `@cache`, `@snapshots`, `@swap` subvolumes on all hosts
- 📸 **Automatic snapshots** — Snapper takes hourly/daily/weekly snapshots of `/` and `/home` on every host
- 🔐 **agenix secrets** — SSH authorized keys, WireGuard private key, and service passwords are encrypted in the repo; no plaintext secrets in version control
- 🦊 **Firefox enterprise policies** — uBlock Origin, custom filters, search engine, and tracking protection locked in declaratively
- 🎮 **Gaming** — Steam, MangoHud, GameMode, ProtonPlus, Lutris
- 🛡️ **VPN-scoped qBittorrent** — WireGuard network namespace killswitch on babylinux's machines; leaks are structurally impossible
- 🎬 **Media server** — Plex, Sonarr, Radarr, Prowlarr, Lidarr, Readarr, Bazarr, Immich on dedicated hardware
- 📁 **Samba** — Family file sharing with per-share permissions
- 📰 **FreshRSS** — Self-hosted RSS reader on Radxa-X4
- 🌐 **Tailscale** — Mesh VPN on linuxury's machines
- 🔄 **Weekly auto-updates** — All hosts rebuild automatically
- 🐟 **Fish + Starship + Ghostty** — Terminal environment with NixOS management aliases

---

## 🖥️ Hosts

| Host | Primary User | Role | LUKS | GPU |
|------|-------------|------|------|-----|
| **ThinkPad** | linuxury | Laptop daily driver | Yes | AMD |
| **Ryzen5900x** | linuxury | Desktop daily driver | No | AMD |
| **Ryzen5800x** | babylinux | Wife's desktop | No | AMD |
| **Asus-A15** | babylinux | Wife's laptop | Yes | Nvidia hybrid |
| **Alex-Desktop** | alex | Kid's desktop | No | AMD |
| **Alex-Laptop** | alex | Kid's laptop | No | AMD |
| **MinisForum** | linuxury | Game server (Hytale) | No | Intel |
| **Radxa-X4** | linuxury | FreshRSS server | No | Intel |
| **Media-Server** | linuxury | Plex + Arr stack | No | AMD |

---

## 📁 Structure

```
nixos-config/
├── flake.nix                          # Entry point — all hosts defined here
├── hosts/                             # Per-host configuration
│   ├── ThinkPad/
│   ├── Ryzen5900x/
│   ├── Ryzen5800x/
│   ├── Asus-A15/
│   ├── Alex-Desktop/
│   ├── Alex-Laptop/
│   ├── MinisForum/
│   ├── Radxa-X4/
│   └── Media-Server/
├── modules/
│   ├── base/
│   │   ├── common.nix                 # Shared by ALL hosts
│   │   ├── snapper.nix                # BTRFS automatic snapshots
│   │   ├── linuxury-ssh.nix           # agenix SSH key for linuxury
│   │   ├── auto-update.nix            # Weekly rebuild + sudo rules
│   │   └── firefox.nix                # Enterprise Firefox policies
│   ├── hardware/
│   │   └── drivers.nix                # AMD / Nvidia / Intel GPU logic
│   ├── desktop-environments/
│   │   ├── cosmic.nix
│   │   ├── hyprland.nix
│   │   ├── kde.nix
│   │   └── niri.nix
│   ├── gaming/
│   │   └── gaming.nix                 # Steam, MangoHud, GameMode, Proton
│   ├── development/
│   │   └── development.nix            # Python, Rust
│   └── services/
│       ├── samba.nix                  # Samba base config
│       ├── vpn-qbittorrent.nix        # WireGuard namespace killswitch
│       └── wallpaper-slideshow.nix    # systemd timer + matugen theming
├── users/                             # Home Manager configs
│   ├── linuxury/
│   ├── babylinux/
│   └── alex/
├── dotfiles/                          # Config files managed by Home Manager
│   ├── fish/
│   ├── ghostty/
│   ├── helix/
│   ├── starship/
│   ├── fastfetch/
│   ├── MangoHud/
│   └── nano/
├── secrets/                           # age-encrypted secrets (safe to commit)
│   ├── secrets.nix                    # Declares recipients for each secret
│   ├── linuxury-authorized-key.age
│   ├── wireguard-vpnunlimited.age
│   └── freshrss-admin-password.age
├── assets/                            # Wallpapers, SteamGridDB art, etc.
└── docs/
    ├── admin-setup.md                 # One-time admin machine bootstrap (SSH keys, agenix)
    └── manual-steps.md                # Post-deploy steps that can't be automated
```

---

## 🔧 One-time Admin Setup

Do this once on the machine you manage the flake from — currently **ThinkPad** and **Ryzen5900x**. You do not repeat this per host.

Steps: generate SSH key → clone repo → add key to `secrets.nix` → create encrypted secrets → set git remote to SSH.

**Full walkthrough:** [`docs/admin-setup.md`](docs/admin-setup.md)

---

## 🚀 Installing a Host

> Three shell variables drive every command in this guide: `DISK`, `HOST`, and `NIXUSER`.
> You set them once in Step 4 — after that every code block is copy-pasteable without edits.

### Step 1 — Boot the NixOS minimal ISO

Download the [NixOS minimal ISO](https://nixos.org/download) and boot it on the target machine.

Once at the shell, improve the console font if the text is hard to read:

```bash
setfont ter-118b
```

### Step 2 — Connect to the network

Test if the network is already working:

```bash
ping -c 3 nixos.org
```

**If it works:** skip to Step 3.

**If you need WiFi:**

```bash
nmtui
```

In the nmtui interface:
- Select **"Activate a connection"**
- Choose your WiFi interface
- Select your network SSID
- Enter password and connect
- Exit and verify:

```bash
ping -c 3 nixos.org
```

⚠️ **Do not continue until networking works.** The installer needs internet access to download packages.

### Step 3 — Enable SSH and connect from your admin machine

On the target machine (local keyboard):

```bash
sudo passwd root            # Set a temporary root password for this session
sudo systemctl start sshd
ip addr                     # Note the IP address
```

Example output — look for `inet` next to your network interface:

```
2: enp3s0: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
    inet 192.168.1.42/24 ...     ← this is the IP you want
```

On your admin machine:

```bash
# Ensure your key is loaded into the agent — required for forwarding to work
ssh-add ~/.ssh/id_ed25519

# Verify a key is present before connecting
ssh-add -l

ssh -A root@192.168.1.42
```

💡 The `-A` flag forwards your SSH agent so git can use your admin machine's GitHub key inside the live ISO — no need to copy your private key to the target. **The `ssh-add` step is mandatory:** if the agent has no keys loaded the forwarding socket is created but empty, and `git clone` will fail with "Permission denied (publickey)" even though `-A` was used.

**All remaining steps run over this SSH session.**

### Step 4 — Identify the target disk

```bash
lsblk
```

Example output:

```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:0    0 476.9G  0 disk              ← NVMe SSD
├─nvme0n1p1 259:1    0   512M  0 part
└─nvme0n1p2 259:2    0 476.4G  0 part
sda           8:0    0   1.8T  0 disk              ← SATA drive
└─sda1        8:1    0   1.8T  0 part
```

Common disk names:
- **NVMe SSD:** `/dev/nvme0n1`, `/dev/nvme1n1` — partitions are `p1`, `p2`, etc.
- **SATA SSD/HDD:** `/dev/sda`, `/dev/sdb` — partitions are `1`, `2`, etc.
- **eMMC (some laptops):** `/dev/mmcblk0` — partitions are `p1`, `p2`, etc.

⚠️ **Warning:** Double-check the disk name and size before continuing. The next step erases all data on the selected disk.

💡 **Tip:** The target disk is usually the largest one that does not have `TYPE = rom`.

Set these three variables once — every command from here forward uses them:

```bash
export DISK=/dev/nvme0n1   # replace with your actual disk — see lsblk output above
export HOST=Ryzen5900x     # hostname from flake.nix — see table below
export NIXUSER=linuxury    # primary user for this host — see table below
```

| `HOST` | `NIXUSER` | Role |
|--------|-----------|------|
| `ThinkPad` | `linuxury` | Laptop |
| `Ryzen5900x` | `linuxury` | Desktop |
| `Ryzen5800x` | `babylinux` | Wife's desktop |
| `Asus-A15` | `babylinux` | Wife's laptop |
| `Alex-Desktop` | `alex` | Kid's desktop |
| `Alex-Laptop` | `alex` | Kid's laptop |
| `MinisForum` | `linuxury` | Game server |
| `Radxa-X4` | `linuxury` | FreshRSS server |
| `Media-Server` | `linuxury` | Media server |

### Step 5 — Partition the disk

The partition layout is identical for both encrypted and plain setups:

```bash
wipefs -a $DISK

parted $DISK -- mklabel gpt
parted $DISK -- mkpart EFI fat32 1MiB 513MiB
parted $DISK -- set 1 esp on
parted $DISK -- mkpart primary 513MiB 100%
```

### Step 6 — Format the partitions

From here LUKS and plain setups diverge. Follow the column for your host:

<table>
<tr>
<th>Without LUKS &nbsp;—&nbsp; <sub>Ryzen5900x · Ryzen5800x · Alex-Desktop · Alex-Laptop · Servers</sub></th>
<th>With LUKS &nbsp;—&nbsp; <sub>ThinkPad · Asus-A15</sub></th>
</tr>
<tr>
<td>
<code>mkfs.fat -F 32 -n EFI &nbsp; ${DISK}p1</code><br>
<code>mkfs.btrfs -f -L nixos &nbsp; ${DISK}p2</code>
</td>
<td>
<code>mkfs.fat -F 32 -n EFI ${DISK}p1</code><br>
<br>
<em># prompted to set LUKS passphrase</em><br>
<code>cryptsetup luksFormat --label nixos-luks ${DISK}p2</code><br>
<code>cryptsetup open ${DISK}p2 cryptroot</code><br>
<br>
<code>mkfs.btrfs -f -L nixos /dev/mapper/cryptroot</code>
</td>
</tr>
</table>

> For SATA drives, replace `${DISK}p1` / `${DISK}p2` with `${DISK}1` / `${DISK}2`.

### Step 7 — Create BTRFS subvolumes

Set the source device first, then create subvolumes:

<table>
<tr>
<th>Without LUKS</th>
<th>With LUKS</th>
</tr>
<tr>
<td><code>mount /dev/disk/by-label/nixos /mnt</code></td>
<td><code>mount /dev/mapper/cryptroot /mnt</code></td>
</tr>
</table>

```bash
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@swap

umount /mnt
```

### Step 8 — Mount everything

Set the BTRFS device variable to match your setup:

<table>
<tr>
<th>Without LUKS</th>
<th>With LUKS</th>
</tr>
<tr>
<td><code>BTRFS=/dev/disk/by-label/nixos</code></td>
<td><code>BTRFS=/dev/mapper/cryptroot</code></td>
</tr>
</table>

```bash
mount -o subvol=@,compress=zstd:1,noatime           $BTRFS /mnt

mkdir -p /mnt/{boot,home,nix,var/log,var/cache,.snapshots,swap}

mount -o subvol=@home,compress=zstd:1,noatime       $BTRFS /mnt/home
mount -o subvol=@nix,compress=zstd:1,noatime        $BTRFS /mnt/nix
mount -o subvol=@log,compress=zstd:1,noatime        $BTRFS /mnt/var/log
mount -o subvol=@cache,compress=zstd:1,noatime      $BTRFS /mnt/var/cache
mount -o subvol=@snapshots,compress=zstd:1,noatime  $BTRFS /mnt/.snapshots
mount -o subvol=@swap,noatime                       $BTRFS /mnt/swap

mount /dev/disk/by-label/EFI /mnt/boot
```

Verify everything mounted correctly:

```bash
lsblk
```

You should see `/mnt`, `/mnt/home`, `/mnt/nix`, `/mnt/boot`, etc. all listed as mount points.

### Step 9 — Create the swapfile

```bash
btrfs filesystem mkswapfile --size 16G /mnt/swap/swapfile
swapon /mnt/swap/swapfile
```

💡 Adjust the size to match your system. 16G works well for machines with 16–32G RAM.

### Step 10 — Clone the config

The config lives in the primary user's home directory. `/etc/nixos` is symlinked there so NixOS tooling always finds it, and the config stays under version control in a readable/writable location.

```bash
# Verify your variables are set before running anything here
echo "DISK=$DISK  HOST=$HOST  NIXUSER=$NIXUSER"
```

⚠️ **If any variable is blank, stop and re-export it** — an empty `$NIXUSER` will clone to the wrong path and silently break later steps.

```bash
mkdir -p /mnt/home/$NIXUSER

# SSH agent forwarding from Step 3 lets git use your admin machine's GitHub key
git clone git@github.com:linuxury/nixos-config.git /mnt/home/$NIXUSER/nixos-config

# Fix ownership — git clone runs as root, but the user needs to own the repo
chown -R 1000:100 /mnt/home/$NIXUSER/nixos-config

# Symlink /etc/nixos → the config directory (-sf overwrites if retrying)
mkdir -p /mnt/etc
ln -sf /home/$NIXUSER/nixos-config /mnt/etc/nixos

# Verify the symlink points to the right place
ls -la /mnt/etc/nixos
```

### Step 11 — Generate hardware config

```bash
nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/home/$NIXUSER/nixos-config/hosts/$HOST/hardware-configuration.nix
```

Review the generated file to make sure the detected filesystems look right:

```bash
cat /mnt/home/$NIXUSER/nixos-config/hosts/$HOST/hardware-configuration.nix
```

### Step 12 — Install

```bash
nixos-install \
  --flake /mnt/home/$NIXUSER/nixos-config#$HOST \
  --no-root-passwd
```

`--no-root-passwd` skips the root password prompt. `nixos-install` does **not** set user passwords automatically — you must do that in the next step before rebooting.

### Step 12b — Set the user password

⚠️ **Do not skip this step.** Without it the user account has a locked password and you will not be able to log in after reboot.

```bash
echo "Setting password for: $NIXUSER"   # verify the variable before running the next line
nixos-enter --root /mnt -- passwd $NIXUSER
```

`nixos-enter -- <cmd>` runs one command in the chroot and exits automatically. It will prompt you to enter and confirm the password, then return you to the live ISO shell.

### Step 13 — Reboot

```bash
swapoff -a
umount -R /mnt
reboot
```

Remove the USB drive when the machine powers off.

---

## 🔄 After First Boot

### SSH access

**linuxury's machines** — key-based auth works immediately. agenix decrypted the authorized key during the first activation:

```bash
ssh linuxury@ThinkPad
# or by IP if hostname doesn't resolve yet:
ssh linuxury@<ip>
```

**babylinux's and alex's machines** — SSH in with the password set in Step 12b:

```bash
ssh babylinux@Ryzen5800x
ssh alex@Alex-Desktop
```

> linuxury does not have a user account on family machines by design. Remote management is done by SSH-ing in as the primary user, or by pushing config changes to git and letting the weekly auto-update handle them.

### Deploy the SSH key for git access

Each machine gets its own SSH key — do not copy private keys between machines.
Generate a new one on the freshly installed machine:

```bash
ssh-keygen -t ed25519 -C "<hostname>-linuxury"
# Accept the default path (~/.ssh/id_ed25519)

# Add GitHub to known hosts and verify the connection
ssh-keyscan github.com >> ~/.ssh/known_hosts
cat ~/.ssh/id_ed25519.pub   # copy this output
```

Add the public key to GitHub: **github.com → Settings → SSH and GPG keys → New SSH key**.

Verify it works:
```bash
ssh -T git@github.com
# Expected: "Hi Linuxury! You've successfully authenticated..."
```

**Register the key with agenix** so future re-keys can run from this machine.
On any existing admin machine (ThinkPad or Ryzen5900x), add an entry to `secrets/secrets.nix`:

```nix
# In the PERSONAL SSH KEYS section:
newhost-personal = "ssh-ed25519 AAAA...";   # paste the new key here

# Add it to linuxury-admins:
linuxury-admins = [ linuxury-personal thinkpad-personal newhost-personal ];
```

Then re-key and push from that admin machine:

```bash
cd ~/nixos-config
age-rekey
git add secrets/
git commit -m "add <hostname> personal key to linuxury-admins"
git push
```

Pull on the new machine to get the updated secrets:

```bash
cd ~/nixos-config && git pull
```

### Add the new host's SSH key to agenix

Every host has its own SSH host key generated at first boot. Add it to agenix so the machine can decrypt its own secrets on all future rebuilds.

On your admin machine, collect the host key:

```bash
ssh-keyscan -t ed25519 <hostname> | awk '{print $3}'
# or by IP if hostname isn't resolving yet:
ssh-keyscan -t ed25519 <ip> | awk '{print $3}'
```

Open `secrets/secrets.nix` and paste the key next to `<hostname>`. Then re-key all secrets so the new host is included as a recipient.

Re-key can be run from any machine in `linuxury-admins` (currently ThinkPad or Ryzen5900x):

```bash
cd ~/nixos-config
age-rekey
git add secrets/
git commit -m "add <hostname> host key, re-key secrets"
git push
```

Pull and rebuild on the new host to pick up the updated secrets:

```bash
# linuxury's machines:
ssh linuxury@<hostname> "cd ~/nixos-config && git pull && nr"

# family machines — SSH in as the primary user first:
ssh babylinux@Ryzen5800x
cd ~/nixos-config && git pull && nr
```

### Complete post-install manual steps

See `docs/manual-steps.md` for the full list. Common ones:

- **Tailscale:** `sudo tailscale up`
- **Fingerprint (ThinkPad):** `fprintd-enroll`
- **Samba passwords (Media-Server):**
  ```bash
  sudo smbpasswd -a linuxury
  sudo smbpasswd -a babylinux
  sudo smbpasswd -a alex
  ```
- **qBittorrent:** change the default password (`admin` / `adminadmin`) at `http://10.200.200.2:8080`
- **Plex:** open `http://Media-Server:32400/web`, complete setup wizard, enable Hardware-Accelerated Transcoding

---

## 🔁 Reinstalling an Existing Host

Reformatting a machine generates a **new SSH host key** and wipes `~/.ssh/`.
Handle this in two parts: before and after the format.

### Before formatting — back up the personal key

```bash
# Run on your admin machine (or any machine you can SSH from):
scp <hostname>:~/.ssh/id_ed25519     ~/backup-<hostname>-key
scp <hostname>:~/.ssh/id_ed25519.pub ~/backup-<hostname>-key.pub
```

If you have this backup, you can restore it after install and skip updating the personal key in `secrets.nix`.

### After reinstall — update the host key in agenix

The SSH host key **always** regenerates on a fresh install. Collect the new one and re-key from any admin machine:

```bash
# Collect new host key (run on an admin machine after the reinstalled host is up):
ssh-keyscan -t ed25519 <hostname> | awk '{print $3}'
```

Paste it into `secrets/secrets.nix` next to `<hostname>`, replacing the old value. Then re-key and push:

```bash
cd ~/nixos-config
age-rekey
git add secrets/
git commit -m "update <hostname> host key after reinstall"
git push
```

Pull and rebuild on the reinstalled machine:

```bash
ssh <user>@<hostname> "cd ~/nixos-config && git pull && nr"
```

### After reinstall — restore the personal key (if backed up)

```bash
scp ~/backup-<hostname>-key     <hostname>:~/.ssh/id_ed25519
scp ~/backup-<hostname>-key.pub <hostname>:~/.ssh/id_ed25519.pub
ssh <hostname> "chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub"
```

Verify GitHub still works: `ssh -T git@github.com`

### If the personal key was lost (no backup)

Generate a fresh key and register it as if it were a new machine — follow the **Deploy the SSH key for git access** steps above. The old entry in `secrets.nix` can be replaced or left alongside the new one.

---

## ⌨️ Daily Operations

All aliases are available in any Fish terminal after first boot. Defined in `dotfiles/fish/config.fish`. Config lives at `~/nixos-config` and the hostname is picked up automatically from the flake.

### NixOS rebuilds

| Alias | Expands to | When to use |
|-------|-----------|-------------|
| `nr` | `sudo nixos-rebuild switch --flake ~/nixos-config` | After editing the config |
| `nru` | same + `--update-input nixpkgs` | Pull in new package versions |
| `nrb` | `sudo nixos-rebuild boot ...` | After kernel changes (applies on next reboot) |
| `nrt` | `sudo nixos-rebuild test ...` | Test a build without activating it |
| `nrr` | `sudo nixos-rebuild switch --rollback` | Something broke — roll back |
| `ngc` | `sudo nix-collect-garbage --delete-older-than 30d` | Free disk space |
| `ngens` | list generations | See what you can roll back to |

### Secrets (agenix)

| Alias | What it does |
|-------|-------------|
| `age-edit secrets/mysecret.age` | Create or edit an encrypted secret |
| `age-rekey` | Re-encrypt all secrets after adding a new host key |

### Snapshots (Snapper)

| Alias | What it does |
|-------|-------------|
| `snaps` | List system (root) snapshots |
| `snapsh` | List home snapshots |
| `snapc "before big update"` | Create a manual snapshot with a description |

Snapshots are also taken automatically: 8 hourly, 7 daily, 4 weekly. Old ones are pruned automatically.

---

## 🔍 Troubleshooting

### System won't boot

At the systemd-boot menu, select a previous generation from the list. The system boots with the older working configuration. Once running, fix the config and rebuild.

### Network not working after boot

```bash
# Check NetworkManager status
systemctl status NetworkManager

# Restart it
sudo systemctl restart NetworkManager

# Check if an interface is up
ip addr
```

### A rebuild fails

```bash
# Roll back to the last working generation
nrr

# View the full build error
sudo nixos-rebuild switch --flake ~/nixos-config 2>&1 | less
```

### agenix: "secret could not be decrypted"

The host's SSH key is not yet in `secrets/secrets.nix` as a recipient. Follow the **Add the new host's SSH key to agenix** steps above, then re-key and rebuild.

### Check system logs

```bash
# All logs since last boot
journalctl -b

# Follow live logs
journalctl -f

# Logs for a specific service
journalctl -u NetworkManager
journalctl -u vpn-qbt-netns
```

### BTRFS health check

```bash
# Trigger a manual scrub (also runs monthly automatically)
sudo btrfs scrub start /
sudo btrfs scrub status /

# View filesystem usage across subvolumes
sudo btrfs filesystem usage /
```

### Restore a file from a snapshot

```bash
# List available snapshots
snaps

# See what changed between snapshot 5 and now
sudo snapper -c root diff 5..0 /path/to/file

# Restore a specific file to its state at snapshot 5
sudo snapper -c root undochange 5..0 /path/to/file
```

---

## 🔑 Rotating Your SSH Key

Each machine has its own entry in the `linuxury-admins` list in `secrets/secrets.nix`.
To rotate a specific machine's personal key:

1. Generate a new key on the target machine: `ssh-keygen -t ed25519 -C "<hostname>-linuxury"`
2. Add the new public key to GitHub (Settings → SSH keys)
3. In `secrets/secrets.nix`, update the entry for that machine under `linuxury-admins`
4. Update the authorized key secret so hosts accept the new key:
   `age-edit secrets/linuxury-authorized-key.age`
5. Re-key from any admin machine: `age-rekey`
6. Push and rebuild all hosts: push to git, `nr` on each machine (or let auto-update handle it)
7. Verify SSH works with the new key before removing the old entry from `secrets.nix`

---

## ➕ Adding a New Host

1. Create `hosts/NewHost/default.nix` — copy from an existing similar host as a starting point
2. Add the entry to `flake.nix` using `mkHost`
3. Add a placeholder host key in `secrets/secrets.nix`
4. Follow the installation steps above
5. After first boot, fill in the real host key and run `age-rekey`

---

## 📚 Resources

### Official NixOS

- [NixOS Website](https://nixos.org/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Package Search](https://search.nixos.org/)
- [NixOS Wiki](https://wiki.nixos.org/)
- [Home Manager Options](https://nix-community.github.io/home-manager/options.xhtml)

### Community

- [NixOS Discourse](https://discourse.nixos.org/)
- [r/NixOS](https://www.reddit.com/r/NixOS/)
- [NixOS Matrix](https://matrix.to/#/#nixos:nixos.org)

### Tools Used

- [COSMIC](https://system76.com/cosmic) — System76's desktop environment
- [agenix](https://github.com/ryantm/agenix) — age-based secret management for NixOS
- [Ghostty](https://ghostty.org/) — GPU-accelerated terminal
- [Helix](https://helix-editor.com/) — Modal text editor
- [Starship](https://starship.rs/) — Cross-shell prompt
- [Snapper](http://snapper.io/) — BTRFS snapshot management

---

## 📝 License

MIT License — Feel free to use and adapt for your own systems.

---

**Happy NixOS-ing! 🚀**
