# Install — Legacy BIOS + LUKS (Full-Disk Encryption)

This guide installs NixOS on a machine with legacy BIOS firmware and full-disk encryption via LUKS. No current host in this config uses this combination — this guide exists for future machines or edge cases where an older BIOS machine also needs encryption.

**Before starting:** complete [01-getting-started.md](01-getting-started.md) — you should be at the `nixos` shell with the installer running and the console font set. Confirm you booted in Legacy BIOS mode before continuing:

```bash
ls /sys/firmware/efi   # must return "No such file or directory" — if it returns a list, you booted as UEFI
```

---

## How This Differs from the Other Guides

This guide combines two non-standard elements:

- **Legacy BIOS** — no EFI partition; a tiny `bios_grub` partition holds GRUB's second-stage code instead
- **LUKS** — the main partition is wrapped in an encrypted container; BTRFS lives inside it

GRUB on legacy BIOS can unlock a LUKS container at boot time. The BIOS boot partition is never encrypted — GRUB code has to run before any passphrase can be entered. Once GRUB loads and you enter the passphrase, it unlocks the LUKS container and hands off to the kernel.

---

## Contents

- [Step 1 — Connect to the Network](#step-1--connect-to-the-network)
- [Step 2 — Enable SSH and Connect from Your Admin Machine](#step-2--enable-ssh-and-connect-from-your-admin-machine)
- [Step 3 — Identify Your Disk and Set Variables](#step-3--identify-your-disk-and-set-variables)
- [Step 4 — Partition the Disk](#step-4--partition-the-disk)
- [Step 5 — Set Up LUKS and Format the Partition](#step-5--set-up-luks-and-format-the-partition)
- [Step 6 — Create BTRFS Subvolumes](#step-6--create-btrfs-subvolumes)
- [Step 7 — Mount Everything](#step-7--mount-everything)
- [Step 8 — Create the Swapfile](#step-8--create-the-swapfile)
- [Step 9 — Clone the Config](#step-9--clone-the-config)
- [Step 10 — Generate Hardware Config](#step-10--generate-hardware-config)
- [Step 11 — Install](#step-11--install)
- [Step 12 — Set the User Password](#step-12--set-the-user-password)
- [Step 13 — Reboot](#step-13--reboot)
- [After First Boot](#after-first-boot)
- [Reinstalling an Existing Host](#reinstalling-an-existing-host)
- [Common Problems](#common-problems)

---

## Step 1 — Connect to the Network

The NixOS installer downloads everything from the internet — packages, the Nix store, all of it. You cannot proceed without a working network connection.

Test if the network is already working, which is common when connected via ethernet:

```bash
ping -c 3 nixos.org
```

**If the ping succeeded — skip to Step 2.**

If you need Wi-Fi, `nmtui` gives you a simple text-based interface. Navigate with arrow keys and Enter:

```bash
nmtui
```

Select **"Activate a connection"** → find your Wi-Fi network → enter your password → confirm → Escape to exit. Then test again:

```bash
ping -c 3 nixos.org
```

> Do not continue until `ping` succeeds. Every remaining step requires internet access.

---

## Step 2 — Enable SSH and Connect from Your Admin Machine

Typing the entire installation on the target machine's keyboard is tedious and error-prone. SSH in from your admin machine — you get full copy-paste, your shell history, and a comfortable terminal.

**On the target machine** (type these directly on its keyboard — just these three lines):

```bash
sudo passwd root           # set a temporary root password for this SSH session
sudo systemctl start sshd  # start the SSH daemon
ip addr                    # find the IP — look for "inet" followed by something like 192.168.x.x
```

**On your admin machine**, load your key into the SSH agent before connecting. If you skip this, `git clone` will fail later with "Permission denied (publickey)":

```bash
ssh-add ~/.ssh/id_ed25519   # load your key into the agent
ssh-add -l                  # confirm it's loaded — you should see a fingerprint
```

Connect as root with agent forwarding:

```bash
ssh -A root@<ip-address>   # replace with the IP from ip addr above
```

The `-A` flag forwards your SSH agent through the connection. When git asks GitHub for authentication, the request travels back to your admin machine's key — your private key never leaves your admin machine.

**All remaining steps run over this SSH session.**

---

## Step 3 — Identify Your Disk and Set Variables

Run `lsblk` and find the device name and size of your install target:

```bash
lsblk
```

Example output:

```
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda      8:0    0 465.8G  0 disk         ← SATA SSD — likely your target
sdb      8:16   1   7.5G  0 disk         ← USB drive — do not touch
```

Disk naming on legacy machines is typically SATA (`/dev/sda`, `/dev/sdb`) or NVMe (`/dev/nvme0n1`):

| Drive type | Disk name | Partition 1 | Partition 2 |
|-----------|-----------|-------------|-------------|
| SATA SSD/HDD | `/dev/sda` | `sda1` | `sda2` |
| NVMe SSD | `/dev/nvme0n1` | `nvme0n1p1` | `nvme0n1p2` |

> Double-check the disk name and size before moving on. The next step permanently erases everything on the selected disk.

Set the three variables that drive every command from here forward:

```bash
export DISK=/dev/sda   # your actual disk — replace this value
export HOST=YourHost   # your host name — capitalization must match flake.nix exactly
export NIXUSER=user    # the primary user for this host
```

Set the partition suffix:

```bash
[[ "$DISK" == *nvme* || "$DISK" == *mmcblk* ]] && export P="p" || export P=""
```

Verify everything looks right:

```bash
echo "Disk: $DISK  |  Partitions: ${DISK}${P}1 / ${DISK}${P}2  |  Host: $HOST  |  User: $NIXUSER"
```

**Full host and user reference:**

| `HOST` | `NIXUSER` | Machine | Guide |
|--------|-----------|---------|-------|
| `ThinkPad` | `linuxury` | linuxury's laptop | [03-install-luks.md](03-install-luks.md) |
| `Ryzen5900x` | `linuxury` | linuxury's desktop | [02-install-uefi.md](02-install-uefi.md) |
| `Ryzen5800x` | `babylinux` | Milagros' desktop | [02-install-uefi.md](02-install-uefi.md) |
| `Asus-A15` | `babylinux` | Milagros' laptop | [03-install-luks.md](03-install-luks.md) |
| `Alex-Desktop` | `alex` | Alex's desktop | [04-install-legacy-bios.md](04-install-legacy-bios.md) |
| `Alex-Laptop` | `alex` | Alex's laptop | [02-install-uefi.md](02-install-uefi.md) |
| `Media-Server` | `linuxury` | Media server | [02-install-uefi.md](02-install-uefi.md) |
| `Radxa-X4` | `linuxury` | Torrent server | [02-install-uefi.md](02-install-uefi.md) |
| `MinisForum` | `linuxury` | Game server | [02-install-uefi.md](02-install-uefi.md) |

---

## Step 4 — Partition the Disk

The partition layout combines the legacy BIOS requirement (1 MiB `bios_grub` partition for GRUB's embed area) with LUKS (the main partition gets wrapped in an encrypted container). The `bios_grub` partition is never encrypted — GRUB code runs from there before any passphrase is entered.

```bash
wipefs -a $DISK                                    # wipe any existing signatures from the disk

parted $DISK -- mklabel gpt                        # GPT works with legacy BIOS when the bios_grub partition is present
parted $DISK -- mkpart BIOS 1MiB 2MiB             # 1 MiB BIOS boot partition — GRUB embeds its code here
parted $DISK -- set 1 bios_grub on                 # flag this partition for GRUB — no filesystem, never mounted
parted $DISK -- mkpart primary 2MiB 100%           # main partition — LUKS goes here
```

After this: `${DISK}${P}1` is the GRUB embed partition (leave it alone), `${DISK}${P}2` is where LUKS and BTRFS go.

---

## Step 5 — Set Up LUKS and Format the Partition

Only the main partition gets LUKS. The BIOS boot partition is intentionally left unformatted.

When `cryptsetup luksFormat` runs it will ask:

```
Are you sure? (Type 'YES' in capital letters):
```

Type `YES` in all caps exactly as shown, then enter and confirm your passphrase. **Write the passphrase down before running this block — there is no recovery mechanism.**

After `cryptsetup open`, the decrypted container is available at `/dev/mapper/cryptroot`. BTRFS goes inside it.

```bash
cryptsetup luksFormat --label nixos-luks ${DISK}${P}2   # creates the encrypted container — prompts for passphrase
cryptsetup open ${DISK}${P}2 cryptroot                  # decrypts and exposes the container as /dev/mapper/cryptroot

mkfs.btrfs -f -L nixos /dev/mapper/cryptroot            # BTRFS goes inside the container
```

---

## Step 6 — Create BTRFS Subvolumes

BTRFS subvolumes are lightweight independent partitions that all live inside the same filesystem. Rather than splitting the disk into separate partitions for `/`, `/home`, and `/nix`, one big BTRFS partition is carved into subvolumes — each of which can be mounted, snapshotted, and rolled back independently.

| Subvolume | Mount point | Purpose |
|-----------|-------------|---------|
| `@` | `/` | System root — snapshotted independently by Snapper |
| `@home` | `/home` | User home directories — snapshotted independently |
| `@nix` | `/nix` | Nix store — not snapshotted, reproducible from flake |
| `@log` | `/var/log` | System logs — excluded from root snapshots |
| `@cache` | `/var/cache` | Package and app caches — excluded from root snapshots |
| `@snapshots` | `/.snapshots` | Where Snapper stores snapshot data |
| `@swap` | `/swap` | Swapfile — must live on a non-compressed subvolume |

Mount the BTRFS filesystem inside the open LUKS container temporarily, create all subvolumes, then unmount:

```bash
mount /dev/mapper/cryptroot /mnt   # temporary mount of BTRFS inside the open LUKS container

btrfs subvolume create /mnt/@            # system root
btrfs subvolume create /mnt/@home        # user home directories
btrfs subvolume create /mnt/@nix         # Nix store
btrfs subvolume create /mnt/@log         # system logs
btrfs subvolume create /mnt/@cache       # app and package caches
btrfs subvolume create /mnt/@snapshots   # Snapper snapshot storage
btrfs subvolume create /mnt/@swap        # swapfile container

umount /mnt   # unmount before the proper per-subvolume mounts in the next step
```

---

## Step 7 — Mount Everything

Each subvolume gets mounted from `/dev/mapper/cryptroot` — the open LUKS container. There is no EFI partition to mount on this path.

Two mount options apply to every subvolume except swap:

- **`compress=zstd:1`** — transparent compression at level 1. Fast, saves meaningful space. The OS never sees this.
- **`noatime`** — don't update the "last accessed" timestamp on every file read. Performance improvement with no real downside.

The swap subvolume deliberately omits `compress` — BTRFS cannot host a swapfile on a compressed subvolume.

```bash
mount -o subvol=@,compress=zstd:1,noatime           /dev/mapper/cryptroot /mnt   # root subvolume first

mkdir -p /mnt/{home,nix,var/log,var/cache,.snapshots,swap}   # no /boot — GRUB does not need a mounted boot partition

mount -o subvol=@home,compress=zstd:1,noatime        /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,compress=zstd:1,noatime         /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log,compress=zstd:1,noatime         /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@cache,compress=zstd:1,noatime       /dev/mapper/cryptroot /mnt/var/cache
mount -o subvol=@snapshots,compress=zstd:1,noatime   /dev/mapper/cryptroot /mnt/.snapshots
mount -o subvol=@swap,noatime                        /dev/mapper/cryptroot /mnt/swap
```

Run `lsblk` to confirm all mount points are in place. Note that `/mnt/boot` will not appear — that is correct for legacy BIOS.

---

## Step 8 — Create the Swapfile

```bash
btrfs filesystem mkswapfile --size 16G /mnt/swap/swapfile   # create a 16G swapfile with correct BTRFS attributes
swapon /mnt/swap/swapfile                                    # activate it for the current live session
```

> **Size guide:** 16G works well for machines with 16–32G RAM. For hibernation to work reliably, the swapfile should be at least as large as your installed RAM.

---

## Step 9 — Clone the Config

Verify your variables are still set before running these commands:

```bash
echo "Disk: $DISK  |  Host: $HOST  |  User: $NIXUSER"   # all three must show values
```

```bash
mkdir -p /mnt/home/$NIXUSER

git clone git@github.com:linuxury/nixos-config.git /mnt/home/$NIXUSER/nixos-config

chown -R 1000:100 /mnt/home/$NIXUSER/nixos-config

mkdir -p /mnt/etc
ln -sf /home/$NIXUSER/nixos-config /mnt/etc/nixos

ls -la /mnt/etc/nixos
```

---

## Step 10 — Generate Hardware Config

```bash
nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/home/$NIXUSER/nixos-config/hosts/$HOST/hardware-configuration.nix
```

Review the generated file:

```bash
cat /mnt/home/$NIXUSER/nixos-config/hosts/$HOST/hardware-configuration.nix
```

**Required checks for this install type:**

1. **LUKS block** — confirm `boot.initrd.luks.devices` is present. Without this, the system cannot unlock the encrypted partition at boot:

```nix
boot.initrd.luks.devices."cryptroot" = {
  device = "/dev/disk/by-label/nixos-luks";
  allowDiscards = true;
};
```

2. **GRUB config** — the host's NixOS config must use GRUB for legacy BIOS, not systemd-boot. Confirm `hosts/$HOST/default.nix` has:

```nix
boot.loader.grub = {
  enable = true;
  device = "/dev/sda";         # the disk, not a partition
  enableCryptodisk = true;     # allows GRUB to prompt for the LUKS passphrase before loading the kernel
};
boot.loader.systemd-boot.enable = false;
```

3. **No EFI filesystem** — there should be no EFI or `/boot` mount in the filesystems section.

---

## Step 11 — Install

```bash
nixos-install \
  --flake /mnt/home/$NIXUSER/nixos-config#$HOST \
  --no-root-passwd
```

If you get `repository is not owned by current user`, git is refusing to read a repo cloned as another user. Add it to the safe directory list and retry:

```bash
git config --global --add safe.directory /mnt/home/$NIXUSER/nixos-config
nixos-install --flake /mnt/home/$NIXUSER/nixos-config#$HOST --no-root-passwd
```

You will see a lot of output as packages download and build — that is normal. If the command exits with an error, scroll up past the activation output to find the actual build failure.

---

## Step 12 — Set the User Password

> Do not skip this step. The user account was created but has a locked password. If you reboot without setting it, you will not be able to log in.

```bash
echo "Setting password for: $NIXUSER"
nixos-enter --root /mnt -- passwd $NIXUSER
```

---

## Step 13 — Reboot

```bash
swapoff -a
umount -R /mnt
reboot
```

Remove the USB drive when the machine powers off. On the next boot, GRUB loads and prompts for your LUKS passphrase. Enter it and the system continues booting normally.

---

## After First Boot

Continue with **[06-first-boot.md](06-first-boot.md)** which covers:

- Connect to Tailscale
- Generate the machine's SSH key and register it on GitHub
- Register the machine in `secrets/secrets.nix` and re-key agenix
- Clone wallpapers and other assets
- Any host-specific manual steps

---

## Reinstalling an Existing Host

### Before Formatting — Back Up the Personal Key

```bash
scp <hostname>:~/.ssh/id_ed25519     ~/backup-<hostname>-key
scp <hostname>:~/.ssh/id_ed25519.pub ~/backup-<hostname>-key.pub
```

### After Reinstall — Update the Host Key in secrets.nix

```bash
ssh-keyscan -t ed25519 <hostname> | awk '{print $3}'
```

Paste the new key into `secrets/secrets.nix`, then:

```bash
cd ~/nixos-config
age-rekey
git add secrets/
git commit -m "update <hostname> host key after reinstall"
git push
```

```bash
ssh <user>@<hostname> "cd ~/nixos-config && git pull && nr"
```

### After Reinstall — Restore the Personal Key

```bash
scp ~/backup-<hostname>-key     <hostname>:~/.ssh/id_ed25519
scp ~/backup-<hostname>-key.pub <hostname>:~/.ssh/id_ed25519.pub
ssh <hostname> "chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub"
ssh -T git@github.com
```

---

## Common Problems

| Problem | Fix |
|---------|-----|
| `ls /sys/firmware/efi` returns a list instead of "not found" | You booted in UEFI mode — go into firmware settings, enable CSM/Legacy boot, and redo the install |
| `git clone` fails: "Permission denied (publickey)" | Run `ssh-add ~/.ssh/id_ed25519` on your admin machine, then reconnect with `ssh -A root@<ip>` |
| `nixos-install` fails: "flake does not provide attribute" | `$HOST` must match `flake.nix` exactly — it is case-sensitive |
| `echo $HOST` shows nothing | SSH session dropped — re-export all three variables before continuing |
| Boot hangs asking for passphrase, keyboard does nothing | Add `boot.initrd.availableKernelModules = ["usbhid" "xhci_pci"]` to the host's NixOS config |
| GRUB does not prompt for passphrase — boots to emergency shell | `enableCryptodisk = true` is missing from `boot.loader.grub` in the host config |
| System boots to "no bootable device" | GRUB did not install — confirm `boot.loader.grub.device` is the disk path, not a partition |
| Can't log in after first boot | Password wasn't set — boot the ISO again and run `nixos-enter --root /mnt -- passwd $NIXUSER` |
