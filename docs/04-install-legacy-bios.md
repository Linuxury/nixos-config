# Install — Legacy BIOS (No Encryption)

This guide installs NixOS on a machine with a legacy BIOS firmware (non-UEFI), without full-disk encryption. It applies to:

| Host | User |
|------|------|
| Alex-Desktop | alex |

**Before starting:** complete [01-getting-started.md](01-getting-started.md) — you should be at the `nixos` shell with the installer running and the console font set. Confirm you booted in Legacy BIOS mode before continuing:

```bash
ls /sys/firmware/efi   # must return "No such file or directory" — if it returns a list, you booted as UEFI
```

---

## How Legacy BIOS Boot Works

On UEFI machines, the firmware reads the bootloader from a dedicated FAT32 EFI partition. On legacy BIOS machines, the firmware reads a small piece of boot code directly from the first sectors of the disk (the MBR), which then finds and launches the main bootloader.

With GPT partition tables (which we use here), there is no room in the MBR for the full GRUB bootloader. Instead, a tiny unformatted partition of 1 MiB is reserved at the start of the disk with the `bios_grub` flag — GRUB embeds its second-stage code there. This partition has no filesystem, no label, and is never mounted. It is just reserved space for GRUB.

The rest of the disk layout — BTRFS, subvolumes, swapfile — is identical to the UEFI guides. The bootloader is GRUB instead of systemd-boot, but NixOS handles that difference in the host configuration automatically.

---

## Contents

- [Step 1 — Connect to the Network](#step-1--connect-to-the-network)
- [Step 2 — Enable SSH and Connect from Your Admin Machine](#step-2--enable-ssh-and-connect-from-your-admin-machine)
- [Step 3 — Identify Your Disk and Set Variables](#step-3--identify-your-disk-and-set-variables)
- [Step 4 — Partition the Disk](#step-4--partition-the-disk)
- [Step 5 — Format the Partition](#step-5--format-the-partition)
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

Disk naming on legacy machines is typically SATA (`/dev/sda`, `/dev/sdb`) or NVMe (`/dev/nvme0n1`). SATA drives do not use the `p` suffix before the partition number:

| Drive type | Disk name | Partition 1 | Partition 2 |
|-----------|-----------|-------------|-------------|
| SATA SSD/HDD | `/dev/sda` | `sda1` | `sda2` |
| NVMe SSD | `/dev/nvme0n1` | `nvme0n1p1` | `nvme0n1p2` |

> Double-check the disk name and size before moving on. The next step permanently erases everything on the selected disk.

Set the three variables that drive every command from here forward. Set them once and every code block is copy-pasteable without editing:

```bash
export DISK=/dev/sda   # your actual disk — replace this value
export HOST=Alex-Desktop
export NIXUSER=alex
```

Set the partition suffix — this detects whether your disk needs a `p` between the name and the partition number:

```bash
[[ "$DISK" == *nvme* || "$DISK" == *mmcblk* ]] && export P="p" || export P=""
```

Verify everything looks right — all four values must be non-empty before continuing:

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
| `Alex-Desktop` | `alex` | Alex's desktop | this guide |
| `Alex-Laptop` | `alex` | Alex's laptop | [02-install-uefi.md](02-install-uefi.md) |
| `Media-Server` | `linuxury` | Media server | [02-install-uefi.md](02-install-uefi.md) |
| `Radxa-X4` | `linuxury` | Torrent server | [02-install-uefi.md](02-install-uefi.md) |
| `MinisForum` | `linuxury` | Game server | [02-install-uefi.md](02-install-uefi.md) |

---

## Step 4 — Partition the Disk

Legacy BIOS boot requires a different partition layout compared to UEFI. Instead of an EFI System Partition, we create a tiny 1 MiB BIOS boot partition at the start of the disk. This partition holds GRUB's second-stage bootloader code — it has no filesystem, no label, and is never mounted by the OS.

The main partition follows immediately and takes all remaining space.

```bash
wipefs -a $DISK                                    # wipe any existing signatures from the disk

parted $DISK -- mklabel gpt                        # GPT works with legacy BIOS when the bios_grub partition is present
parted $DISK -- mkpart BIOS 1MiB 2MiB             # 1 MiB BIOS boot partition — GRUB embeds its code here
parted $DISK -- set 1 bios_grub on                 # flag this partition for GRUB use — no filesystem, never mounted
parted $DISK -- mkpart primary btrfs 2MiB 100%    # main partition — takes everything from 2 MiB to end of disk
```

After this you have two partitions: `${DISK}${P}1` is the GRUB embed partition (do not touch it further) and `${DISK}${P}2` is the main system partition.

> Note: On a SATA disk, partition 1 is `sda1` and partition 2 is `sda2`. On an NVMe disk they would be `nvme0n1p1` and `nvme0n1p2`. The `$P` variable handles this automatically.

---

## Step 5 — Format the Partition

Only the main partition gets formatted — the BIOS boot partition is intentionally left without a filesystem. GRUB writes raw data there at install time.

> **The `-L nixos` label is required.** Every mount in the config references this disk by label (`/dev/disk/by-label/nixos`). If the label is missing or wrong, the system will fail to boot into emergency mode.

```bash
mkfs.btrfs -f -L nixos ${DISK}${P}2    # BTRFS with label "nixos" — the BIOS partition is intentionally skipped
```

---

## Step 6 — Create BTRFS Subvolumes

BTRFS subvolumes are lightweight independent partitions that all live inside the same filesystem. Rather than splitting the disk into separate partitions for `/`, `/home`, and `/nix`, one big BTRFS partition is carved into subvolumes — each of which can be mounted, snapshotted, and rolled back independently.

If you ever need to roll back the system after a bad update, you can restore the `@` subvolume to a previous snapshot without touching `@home`. Your personal files stay exactly as they were. The `@nix` subvolume is never snapshotted — the Nix store is fully reproducible from the flake, so snapshots would just waste space.

| Subvolume | Mount point | Purpose |
|-----------|-------------|---------|
| `@` | `/` | System root — snapshotted independently by Snapper |
| `@home` | `/home` | User home directories — snapshotted independently |
| `@nix` | `/nix` | Nix store — not snapshotted, reproducible from flake |
| `@log` | `/var/log` | System logs — excluded from root snapshots |
| `@cache` | `/var/cache` | Package and app caches — excluded from root snapshots |
| `@snapshots` | `/.snapshots` | Where Snapper stores snapshot data |
| `@swap` | `/swap` | Swapfile — must live on a non-compressed subvolume |

Mount the raw BTRFS filesystem temporarily to create the subvolumes, then unmount:

```bash
mount /dev/disk/by-label/nixos /mnt   # temporary mount — no options needed yet

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

Each subvolume gets mounted at its permanent location under `/mnt` with the correct options. Two mount options apply to every subvolume except swap:

- **`compress=zstd:1`** — transparent compression at level 1. Fast, saves meaningful space (especially on the Nix store which is full of text-heavy files). The OS and apps never see this — files are compressed on disk and decompressed transparently on read.
- **`noatime`** — don't update the "last accessed" timestamp every time a file is read. A significant performance improvement on SSDs with no real downside.

The swap subvolume deliberately omits `compress` — BTRFS cannot host a swapfile on a compressed subvolume and the kernel will refuse to activate it.

There is no EFI partition to mount on this path. GRUB reads the BIOS boot partition directly at install time — it does not need a mount point in the running system.

```bash
mount -o subvol=@,compress=zstd:1,noatime           /dev/disk/by-label/nixos /mnt   # root subvolume first

mkdir -p /mnt/{home,nix,var/log,var/cache,.snapshots,swap}   # no /boot dir — GRUB does not need a mounted boot partition

mount -o subvol=@home,compress=zstd:1,noatime        /dev/disk/by-label/nixos /mnt/home
mount -o subvol=@nix,compress=zstd:1,noatime         /dev/disk/by-label/nixos /mnt/nix
mount -o subvol=@log,compress=zstd:1,noatime         /dev/disk/by-label/nixos /mnt/var/log
mount -o subvol=@cache,compress=zstd:1,noatime       /dev/disk/by-label/nixos /mnt/var/cache
mount -o subvol=@snapshots,compress=zstd:1,noatime   /dev/disk/by-label/nixos /mnt/.snapshots
mount -o subvol=@swap,noatime                        /dev/disk/by-label/nixos /mnt/swap
```

Run `lsblk` to confirm. You should see `/mnt`, `/mnt/home`, `/mnt/nix`, and the other directories as mount points. Note that `/mnt/boot` will not appear — that is correct for legacy BIOS.

---

## Step 8 — Create the Swapfile

Swap gives the kernel somewhere to move memory pages when RAM is full, and it is required for hibernation. We use a swapfile rather than a dedicated swap partition — easier to resize later, and BTRFS fully supports it since kernel 5.0.

The `@swap` subvolume was created without compression specifically for this: BTRFS cannot host a swapfile on a compressed subvolume, and the kernel will refuse to activate it. `btrfs filesystem mkswapfile` creates the file with the correct no-copy-on-write attributes already set.

```bash
btrfs filesystem mkswapfile --size 16G /mnt/swap/swapfile   # create a 16G swapfile with correct BTRFS attributes
swapon /mnt/swap/swapfile                                    # activate it for the current live session
```

> **Size guide:** 16G works well for machines with 16–32G RAM. For hibernation to work reliably, the swapfile should be at least as large as your installed RAM.

---

## Step 9 — Clone the Config

The NixOS config lives in `~/nixos-config` under the primary user's home directory. Clone it directly to its permanent home inside `/mnt/home/$NIXUSER/` — that way it is already in the right place after first boot, under version control, and editable like a normal git repo. A symlink at `/mnt/etc/nixos` points to it so `nixos-rebuild` finds it where it expects.

The SSH agent forwarding from Step 2 is what makes `git clone` work here — no GitHub credentials are stored on the target machine.

First, verify your variables are still set. If your SSH session dropped and you reconnected, they will be gone:

```bash
echo "Disk: $DISK  |  Host: $HOST  |  User: $NIXUSER"   # all three must show values
```

```bash
mkdir -p /mnt/home/$NIXUSER

git clone git@github.com:linuxury/nixos-config.git /mnt/home/$NIXUSER/nixos-config

chown -R 1000:100 /mnt/home/$NIXUSER/nixos-config   # git ran as root; hand ownership to UID 1000 / GID 100

mkdir -p /mnt/etc
ln -sf /home/$NIXUSER/nixos-config /mnt/etc/nixos

ls -la /mnt/etc/nixos   # verify the symlink before moving on
```

---

## Step 10 — Generate Hardware Config

NixOS needs a hardware configuration file specific to this machine — filesystems, kernel modules, CPU and storage features. `nixos-generate-config` detects all of this and writes a ready-to-use Nix file.

`--show-hardware-config` prints the output to stdout so we can redirect it straight into the correct location in the flake:

```bash
nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/home/$NIXUSER/nixos-config/hosts/$HOST/hardware-configuration.nix
```

Review the generated file:

```bash
cat /mnt/home/$NIXUSER/nixos-config/hosts/$HOST/hardware-configuration.nix
```

**Legacy BIOS-specific check:** confirm the file does NOT include `boot.loader.systemd-boot.enable = true` or any EFI-related boot options. If it does, the hardware config was likely generated from a UEFI boot — check that you booted the installer correctly in Legacy BIOS mode.

The host's NixOS config (`hosts/Alex-Desktop/default.nix`) must have GRUB configured for legacy BIOS, not systemd-boot:

```nix
boot.loader.grub = {
  enable = true;
  device = "/dev/sda";   # the disk, not a partition — GRUB installs to the MBR/BIOS boot area
};
boot.loader.systemd-boot.enable = false;
```

Also confirm the BTRFS subvolumes (`@`, `@home`, `@nix`, etc.) appear with the correct mount points and options. There should be no EFI or `/boot` mount in the filesystems section.

---

## Step 11 — Install

This builds and installs the actual system. `nixos-install` reads your flake, resolves every package and configuration option for this host, downloads what is not already cached, builds everything, and writes the result to `/mnt`.

The first install takes the longest — you are downloading from a cold cache. Subsequent installs on the same machine are much faster.

`--no-root-passwd` skips the interactive root password prompt at the end. The user account set up in the next step is what you use to log in, and `sudo` is configured declaratively in the flake.

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

You will see a lot of output as packages download and build — that is normal. If the command exits with an error, scroll up past the activation output to find the actual build failure — it appears well before the end of the output.

---

## Step 12 — Set the User Password

> Do not skip this step. The user account was created by the install but has a locked password. If you reboot without setting it here, you will not be able to log in — and you will have to boot the ISO again.

`nixos-enter` runs a command inside the installed system's chroot. It is the correct way to interact with the new system before rebooting — it gives the command the correct environment of the installed system rather than the live ISO.

```bash
echo "Setting password for: $NIXUSER"        # final check that the variable is correct
nixos-enter --root /mnt -- passwd $NIXUSER   # set the user password in the installed system
```

It will prompt for the new password twice, then return you to the ISO shell.

---

## Step 13 — Reboot

Unmount everything cleanly before rebooting:

```bash
swapoff -a      # deactivate the swapfile first
umount -R /mnt  # recursively unmount all subvolume mounts in dependency order
reboot
```

Remove the USB drive when the machine powers off. On the next boot GRUB loads from the disk and brings the system straight to the login screen.

---

## After First Boot

The system is installed and running your flake config. Continue with **[06-first-boot.md](06-first-boot.md)** which covers:

- Connect to Tailscale
- Generate the machine's SSH key and register it on GitHub
- Register the machine in `secrets/secrets.nix` and re-key agenix
- Clone wallpapers and other assets
- Any host-specific manual steps

---

## Reinstalling an Existing Host

A reinstall wipes the disk and generates a new SSH host key. Two things need handling: backing up the personal SSH key before the wipe, and updating the host key in `secrets/secrets.nix` after.

### Before Formatting — Back Up the Personal Key

Run this on your admin machine before wiping anything:

```bash
scp <hostname>:~/.ssh/id_ed25519     ~/backup-<hostname>-key
scp <hostname>:~/.ssh/id_ed25519.pub ~/backup-<hostname>-key.pub
```

### After Reinstall — Update the Host Key in secrets.nix

The SSH host key always regenerates on a fresh install. Once the machine is back online, collect the new key from your admin machine:

```bash
ssh-keyscan -t ed25519 <hostname> | awk '{print $3}'   # prints the new host public key
```

Paste it into `secrets/secrets.nix` next to `<hostname>`, replacing the old value. Then re-key:

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

### After Reinstall — Restore the Personal Key

```bash
scp ~/backup-<hostname>-key     <hostname>:~/.ssh/id_ed25519
scp ~/backup-<hostname>-key.pub <hostname>:~/.ssh/id_ed25519.pub
ssh <hostname> "chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub"
ssh -T git@github.com   # verify GitHub still accepts the restored key
```

---

## Common Problems

| Problem | Fix |
|---------|-----|
| `ls /sys/firmware/efi` returns a list instead of "not found" | You booted in UEFI mode — go into firmware settings, enable CSM/Legacy boot, and reinstall the USB |
| `git clone` fails: "Permission denied (publickey)" | Run `ssh-add ~/.ssh/id_ed25519` on your admin machine, then reconnect with `ssh -A root@<ip>` |
| `nixos-install` fails: "flake does not provide attribute" | `$HOST` must match `flake.nix` exactly — it is case-sensitive (`Alex-Desktop` not `alex-desktop`) |
| `echo $HOST` shows nothing | SSH session dropped and variables were lost — re-export all three before continuing |
| System boots to a blank screen or "no bootable device" | GRUB did not install — confirm `boot.loader.grub.device` in the host config matches the actual disk (`/dev/sda`, not a partition) |
| System boots to emergency shell | Run `journalctl -b` — usually a subvolume mount option mismatch in the generated hardware config |
| Can't log in after first boot | Password wasn't set — boot the ISO again and run `nixos-enter --root /mnt -- passwd $NIXUSER` |
| Machine still boots old OS after install | The firmware is not using the disk as the first boot device — enter BIOS and move it to the top of the boot order |
