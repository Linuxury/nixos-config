# 🖥️ Installation Guide

This guide walks you through installing NixOS from scratch on any machine in this config — from booting the ISO to a fully working system with your flake applied. It covers both encrypted (LUKS) and unencrypted installs, and handles both fresh installs and reinstalls of existing hosts.

---

## 📋 Contents

- [Before You Start](#before-you-start)
- [How This Guide Works](#how-this-guide-works)
- [Step 1 — Boot the NixOS Minimal ISO](#step-1--boot-the-nixos-minimal-iso)
- [Step 2 — Connect to the Network](#step-2--connect-to-the-network)
- [Step 3 — Enable SSH and Connect from Your Admin Machine](#step-3--enable-ssh-and-connect-from-your-admin-machine)
- [Step 4 — Identify Your Disk and Set Variables](#step-4--identify-your-disk-and-set-variables)
- [Step 5 — Partition the Disk](#step-5--partition-the-disk)
- [Step 6 — Format the Partitions](#step-6--format-the-partitions)
  - [Step 6a — Without LUKS](#step-6a--without-luks)
  - [Step 6b — With LUKS](#step-6b--with-luks)
- [Step 7 — Create BTRFS Subvolumes](#step-7--create-btrfs-subvolumes)
  - [Step 7a — Without LUKS](#step-7a--without-luks)
  - [Step 7b — With LUKS](#step-7b--with-luks)
- [Step 8 — Mount Everything](#step-8--mount-everything)
  - [Step 8a — Without LUKS](#step-8a--without-luks)
  - [Step 8b — With LUKS](#step-8b--with-luks)
- [Step 9 — Create the Swapfile](#step-9--create-the-swapfile)
- [Step 10 — Clone the Config](#step-10--clone-the-config)
- [Step 11 — Generate Hardware Config](#step-11--generate-hardware-config)
- [Step 12 — Install](#step-12--install)
- [Step 13 — Set the User Password](#step-13--set-the-user-password)
- [Step 14 — Reboot](#step-14--reboot)
- [After First Boot](#after-first-boot)
- [Reinstalling an Existing Host](#reinstalling-an-existing-host)
- [Common Problems](#common-problems)

---

## Before You Start

**What you need:**
- A USB drive (4 GB minimum) to flash the ISO
- Your admin machine (ThinkPad or Ryzen5900x) — you'll SSH in from it and do everything comfortably
- The target machine connected to a network (ethernet is strongly recommended)
- About 30–60 minutes — most of that is waiting on downloads

**What you end up with:**
- NixOS with BTRFS on all partitions
- Separate subvolumes for system, home, Nix store, logs, caches, snapshots, and swap
- Automatic snapshots via Snapper
- Full-disk encryption (LUKS) if the machine is a laptop that leaves the house
- Your flake config fully applied from the first boot

---

## How This Guide Works

**Three shell variables drive every command in this guide.** You set them once in Step 4 and every code block from that point is copy-pasteable without editing. If your SSH session drops at any point and you reconnect, the variables will be gone — re-export all three before continuing.

**The guide splits at Step 6** into two completely independent paths — one for encrypted installs and one for plain installs. Each path has its own sections with a direct link to the next step at the end, so you never need to read the other path. The paths rejoin at Step 9.

| Path | Hosts |
|------|-------|
| 🔓 **Without LUKS** | Ryzen5900x, Ryzen5800x, Alex-Desktop, Alex-Laptop, all servers |
| 🔐 **With LUKS** | ThinkPad, Asus-A15 — laptops that could be stolen |

LUKS encrypts the entire disk with a passphrase. Without it, anyone who physically removes the drive and puts it in another machine can read everything on it. With it, they get an encrypted blob — useless without the passphrase. The tradeoff is typing that passphrase every time the machine powers on.

---

## Step 1 — Boot the NixOS Minimal ISO

[↑ Back to Contents](#-contents)

Download the [NixOS minimal ISO](https://nixos.org/download) — choose **x86_64 Linux, minimal**. Do not use the graphical installer ISO; this guide assumes the minimal shell environment.

Flash it to a USB drive using Balena Etcher (GUI, easiest), or from a terminal on your admin machine. Either way, verify which device is the USB with `lsblk` before running `dd` — it will destroy whatever is on the target device without asking:

```bash
sudo dd if=nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync   # replace /dev/sdX with your USB drive
```

Boot the target machine from the USB. You'll land at a shell logged in as `nixos` automatically — no password needed. If the text is tiny or hard to read, fix that before doing anything else:

```bash
setfont ter-118b   # larger console font — makes everything much easier to read
```

→ [Continue to Step 2 — Connect to the Network](#step-2--connect-to-the-network)

---

## Step 2 — Connect to the Network

[↑ Step 1](#step-1--boot-the-nixos-minimal-iso)

The NixOS installer downloads everything from the internet — packages, the Nix store, all of it. You cannot proceed without a working network connection.

Test if the network is already working, which is common when connected via ethernet:

```bash
ping -c 3 nixos.org
```

**If the ping succeeded — skip to Step 3.**

If you need Wi-Fi, `nmtui` gives you a simple text-based interface to connect. Navigate with arrow keys and Enter:

```bash
nmtui
```

In the menu: select **"Activate a connection"** → find your Wi-Fi network → enter your password → confirm → press Escape to exit. Then run the ping again to confirm the connection is working:

```bash
ping -c 3 nixos.org
```

> ⚠️ Do not continue until `ping` succeeds. Every remaining step requires internet access.

→ [Continue to Step 3 — Enable SSH](#step-3--enable-ssh-and-connect-from-your-admin-machine)

---

## Step 3 — Enable SSH and Connect from Your Admin Machine

[↑ Step 2](#step-2--connect-to-the-network)

Typing the entire installation on the target machine's keyboard is tedious and error-prone. Instead, you'll set up SSH access so you can do everything from your admin machine — with full copy-paste, your shell history, and a comfortable terminal.

**On the target machine** (type these directly on its keyboard — just these three lines):

```bash
sudo passwd root           # set a temporary root password — only needed for this SSH session
sudo systemctl start sshd  # start the SSH daemon so remote connections are accepted
ip addr                    # find the machine's IP — look for "inet" followed by something like 192.168.x.x
```

**On your admin machine**, load your key into the SSH agent before connecting. This step is mandatory — if you skip it, `git clone` will fail later with "Permission denied (publickey)" even though you used `-A`:

```bash
ssh-add ~/.ssh/id_ed25519   # load your key into the agent
ssh-add -l                  # confirm it's loaded — you should see a fingerprint, not "The agent has no identities"
```

Now connect to the target as root, forwarding your agent:

```bash
ssh -A root@<ip-address>   # replace with the IP from ip addr above
```

The `-A` flag is what makes `git clone` work without copying your private key to the target. It forwards your SSH agent through the connection, so when git asks GitHub for authentication, the request is forwarded back to your admin machine's key. Your private key never leaves your admin machine.

**All remaining steps run over this SSH session on the target machine.**

→ [Continue to Step 4 — Identify Your Disk](#step-4--identify-your-disk-and-set-variables)

---

## Step 4 — Identify Your Disk and Set Variables

[↑ Step 3](#step-3--enable-ssh-and-connect-from-your-admin-machine)

Before touching any disk, you need to identify exactly which device is the install target. Run `lsblk` and look at the device names and sizes:

```bash
lsblk
```

Example output:

```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:0    0 476.9G  0 disk         ← NVMe SSD — likely your target
sda           8:0    0   1.8T  0 disk         ← external drive — do not touch this one
```

Disk naming follows a pattern based on the hardware type. This matters because NVMe and eMMC drives use a `p` before the partition number, while SATA drives don't — and later steps reference partitions using variables that account for this:

| Drive type | Disk name | Partition 1 | Partition 2 |
|-----------|-----------|-------------|-------------|
| NVMe SSD | `/dev/nvme0n1` | `nvme0n1p1` | `nvme0n1p2` |
| SATA SSD/HDD | `/dev/sda` | `sda1` | `sda2` |
| eMMC | `/dev/mmcblk0` | `mmcblk0p1` | `mmcblk0p2` |

> ⚠️ Double-check the disk name and size before moving on. The next step permanently erases everything on the selected disk.

Set the three variables that drive the rest of this guide. Every code block from here forward uses them — set them correctly once and nothing else needs to be edited:

```bash
export DISK=/dev/nvme0n1   # your actual disk from lsblk — replace this value
export HOST=ThinkPad       # your host's name from the table below — capitalization must be exact
export NIXUSER=linuxury    # the primary user for this host — see table below
```

Also set the partition suffix. This one-liner detects whether your disk type needs a `p` between the disk name and the partition number:

```bash
[[ "$DISK" == *nvme* || "$DISK" == *mmcblk* ]] && export P="p" || export P=""
```

Verify everything looks right before continuing. All four values must be non-empty:

```bash
echo "Disk: $DISK  |  Partitions: ${DISK}${P}1 / ${DISK}${P}2  |  Host: $HOST  |  User: $NIXUSER"
```

**Host and user reference:**

| `HOST` | `NIXUSER` | Machine |
|--------|-----------|---------|
| `ThinkPad` | `linuxury` | Your laptop |
| `Ryzen5900x` | `linuxury` | Your desktop |
| `Ryzen5800x` | `babylinux` | Milagros' desktop |
| `Asus-A15` | `babylinux` | Milagros' laptop |
| `Alex-Desktop` | `alex` | Alex's desktop |
| `Alex-Laptop` | `alex` | Alex's laptop |
| `MinisForum` | `linuxury` | Game server |
| `Radxa-X4` | `linuxury` | Torrent server |
| `Media-Server` | `linuxury` | Media server |

→ [Continue to Step 5 — Partition the Disk](#step-5--partition-the-disk)

---

## Step 5 — Partition the Disk

[↑ Step 4](#step-4--identify-your-disk-and-set-variables)

This step creates two partitions on the target disk. The layout is the same for both encrypted and plain installs — LUKS wraps the filesystem inside a partition, it doesn't change the partition structure itself.

The first partition is small (512 MiB) and holds the bootloader — this is the EFI System Partition, required for UEFI boot on all modern hardware. The second partition takes everything else: your root filesystem, home directory, Nix store, logs, caches, and swap all live inside it via BTRFS subvolumes. We use GPT (GUID Partition Table) rather than the older MBR format — it's required for UEFI and handles large disks correctly.

```bash
wipefs -a $DISK                                   # wipe any existing partition table or filesystem signatures from the disk

parted $DISK -- mklabel gpt                       # create a fresh GPT partition table
parted $DISK -- mkpart EFI fat32 1MiB 513MiB      # 512 MiB EFI partition — holds the bootloader, always unencrypted
parted $DISK -- set 1 esp on                      # mark partition 1 as the EFI System Partition (required for UEFI)
parted $DISK -- mkpart primary 513MiB 100%        # main partition — gets everything from 513 MiB to the end of the disk
```

After this completes you have two partitions: `${DISK}${P}1` for EFI and `${DISK}${P}2` for the main system. Neither has a filesystem yet — that happens in Step 6.

→ [Continue to Step 6 — Format the Partitions](#step-6--format-the-partitions)

---

## Step 6 — Format the Partitions

[↑ Step 5](#step-5--partition-the-disk)

The EFI partition always gets FAT32 — that is a hard requirement of the UEFI standard, no exceptions. The main partition is where the two install paths diverge: a plain BTRFS filesystem for unencrypted installs, or a LUKS encrypted container with BTRFS inside it for encrypted ones.

**Which path are you on?**

- [🔓 Without LUKS](#step-6a--without-luks) — Ryzen5900x, Ryzen5800x, Alex-Desktop, Alex-Laptop, all servers
- [🔐 With LUKS](#step-6b--with-luks) — ThinkPad, Asus-A15

---

### Step 6a — Without LUKS

[↑ Step 6](#step-6--format-the-partitions)

For machines that stay in the house, encryption adds boot-time friction with minimal security benefit. Both partitions get formatted directly — FAT32 for EFI, BTRFS for the main partition.

The labels (`EFI` and `nixos`) are important: later steps and the generated NixOS config reference the disk by label (e.g. `/dev/disk/by-label/nixos`) rather than by device path. This makes the config portable across machines regardless of whether the disk shows up as `nvme0n1` or `sda`.

```bash
mkfs.fat -F 32 -n EFI ${DISK}${P}1     # FAT32 with label "EFI" — required format for UEFI boot partition
mkfs.btrfs -f -L nixos ${DISK}${P}2    # BTRFS with label "nixos" — -f forces format even if old data exists
```

→ [Continue to Step 7a — Create BTRFS Subvolumes (Without LUKS)](#step-7a--without-luks)

---

### Step 6b — With LUKS

[↑ Step 6](#step-6--format-the-partitions)

For laptops that leave the house, LUKS wraps the main partition in an encrypted container. When the machine boots, it stops before loading the OS and asks for a passphrase. If the correct passphrase is entered, it decrypts the container and continues booting normally. If the drive is removed and put in another machine without the passphrase, the contents are completely unreadable.

The EFI partition is never encrypted — the bootloader needs to be readable before any passphrase is entered. Only the main partition goes into LUKS.

When `cryptsetup luksFormat` runs, it will ask **"Are you sure? (Type 'YES' in capital letters):"** — type `YES` in all caps exactly as shown, then enter and confirm your passphrase. **There is no recovery mechanism.** If you forget it, the data is gone. Write it down somewhere safe before running this block.

After `cryptsetup open`, all remaining work happens inside `/dev/mapper/cryptroot`. The LUKS layer is transparent to BTRFS and NixOS — they see a normal block device and don't know or care that it's encrypted underneath.

```bash
mkfs.fat -F 32 -n EFI ${DISK}${P}1                    # FAT32 with label "EFI" — always unencrypted, bootloader lives here
cryptsetup luksFormat --label nixos-luks ${DISK}${P}2  # creates the encrypted container — will prompt for a passphrase
cryptsetup open ${DISK}${P}2 cryptroot                 # decrypts and exposes the container as /dev/mapper/cryptroot
mkfs.btrfs -f -L nixos /dev/mapper/cryptroot           # BTRFS goes inside the container, not directly on the partition
```

→ [Continue to Step 7b — Create BTRFS Subvolumes (With LUKS)](#step-7b--with-luks)

---

## Step 7 — Create BTRFS Subvolumes

[↑ Step 6](#step-6--format-the-partitions)

BTRFS subvolumes are like lightweight independent partitions that all live inside the same filesystem. Rather than splitting the disk into separate partitions for `/`, `/home`, and `/nix`, we use one big BTRFS partition and carve it into subvolumes — each of which can be mounted, snapshotted, and rolled back independently.

The reason this matters: if you ever need to roll back the system after a bad update, you can restore the `@` subvolume to a previous snapshot without touching `@home`. Your personal files stay exactly as they were. Conversely, if you need to restore a personal file from a snapshot, you do it on `@home` without touching the system. The `@nix` subvolume is never snapshotted — the Nix store is fully reproducible from the flake, so snapshots would just waste space.

| Subvolume | Mount point | Purpose |
|-----------|-------------|---------|
| `@` | `/` | System root — snapshotted independently by Snapper |
| `@home` | `/home` | User home directories — snapshotted independently |
| `@nix` | `/nix` | Nix store — not snapshotted, reproducible from flake |
| `@log` | `/var/log` | System logs — excluded from root snapshots |
| `@cache` | `/var/cache` | Package and app caches — excluded from root snapshots |
| `@snapshots` | `/.snapshots` | Where Snapper stores snapshot data |
| `@swap` | `/swap` | Swapfile — must live on a non-compressed subvolume |

**Which path are you on?**

- [🔓 Without LUKS](#step-7a--without-luks)
- [🔐 With LUKS](#step-7b--with-luks)

---

### Step 7a — Without LUKS

[↑ Step 7](#step-7--create-btrfs-subvolumes)

To create subvolumes, you first mount the raw BTRFS filesystem temporarily — just so you have a path to work inside it. After creating all the subvolumes you unmount it immediately. The permanent, properly-configured mounts happen in the next step.

```bash
mount /dev/disk/by-label/nixos /mnt   # temporary mount of the raw BTRFS filesystem — no options needed yet

btrfs subvolume create /mnt/@            # system root — will be mounted at /
btrfs subvolume create /mnt/@home        # user home directories — will be mounted at /home
btrfs subvolume create /mnt/@nix         # Nix store — will be mounted at /nix
btrfs subvolume create /mnt/@log         # system logs — will be mounted at /var/log
btrfs subvolume create /mnt/@cache       # app and package caches — will be mounted at /var/cache
btrfs subvolume create /mnt/@snapshots   # Snapper snapshot storage — will be mounted at /.snapshots
btrfs subvolume create /mnt/@swap        # swapfile container — will be mounted at /swap

umount /mnt   # done — unmount before the proper per-subvolume mounts in the next step
```

→ [Continue to Step 8a — Mount Everything (Without LUKS)](#step-8a--without-luks)

---

### Step 7b — With LUKS

[↑ Step 7](#step-7--create-btrfs-subvolumes)

The LUKS container is already open as `/dev/mapper/cryptroot` from Step 6b. The process is identical to the non-LUKS path — mount it temporarily, create all subvolumes, then unmount so the proper mounts can happen in the next step.

```bash
mount /dev/mapper/cryptroot /mnt   # temporary mount of the BTRFS filesystem inside the open LUKS container

btrfs subvolume create /mnt/@            # system root — will be mounted at /
btrfs subvolume create /mnt/@home        # user home directories — will be mounted at /home
btrfs subvolume create /mnt/@nix         # Nix store — will be mounted at /nix
btrfs subvolume create /mnt/@log         # system logs — will be mounted at /var/log
btrfs subvolume create /mnt/@cache       # app and package caches — will be mounted at /var/cache
btrfs subvolume create /mnt/@snapshots   # Snapper snapshot storage — will be mounted at /.snapshots
btrfs subvolume create /mnt/@swap        # swapfile container — will be mounted at /swap

umount /mnt   # done — unmount before the proper per-subvolume mounts in the next step
```

→ [Continue to Step 8b — Mount Everything (With LUKS)](#step-8b--with-luks)

---

## Step 8 — Mount Everything

[↑ Step 7](#step-7--create-btrfs-subvolumes)

Each subvolume now gets mounted at its permanent location under `/mnt`, with the correct options. Two mount options are applied to every subvolume except swap:

- **`compress=zstd:1`** — transparent compression at level 1. Fast and still saves meaningful space, especially on the Nix store which is full of text-heavy files. The OS and apps never see this — files are compressed on disk and decompressed transparently on read.
- **`noatime`** — don't update the "last accessed" timestamp every time a file is read. A significant performance improvement on SSDs with no real downside for a desktop or server system.

The swap subvolume deliberately omits `compress` — BTRFS cannot host a swapfile on a compressed subvolume, and the kernel will refuse to activate it.

**Which path are you on?**

- [🔓 Without LUKS](#step-8a--without-luks)
- [🔐 With LUKS](#step-8b--with-luks)

---

### Step 8a — Without LUKS

[↑ Step 8](#step-8--mount-everything)

The root subvolume (`@`) must be mounted first since all other mount points are directories inside it. After mounting `@` at `/mnt`, the `mkdir` line creates all the subdirectories at once, then each remaining subvolume is mounted at its directory.

```bash
mount -o subvol=@,compress=zstd:1,noatime           /dev/disk/by-label/nixos /mnt   # root subvolume first — /mnt must exist before creating subdirs

mkdir -p /mnt/{boot,home,nix,var/log,var/cache,.snapshots,swap}                      # create all mount point directories in one shot

mount -o subvol=@home,compress=zstd:1,noatime        /dev/disk/by-label/nixos /mnt/home
mount -o subvol=@nix,compress=zstd:1,noatime         /dev/disk/by-label/nixos /mnt/nix
mount -o subvol=@log,compress=zstd:1,noatime         /dev/disk/by-label/nixos /mnt/var/log
mount -o subvol=@cache,compress=zstd:1,noatime       /dev/disk/by-label/nixos /mnt/var/cache
mount -o subvol=@snapshots,compress=zstd:1,noatime   /dev/disk/by-label/nixos /mnt/.snapshots
mount -o subvol=@swap,noatime                        /dev/disk/by-label/nixos /mnt/swap   # no compression — swapfile requires this

mount /dev/disk/by-label/EFI /mnt/boot   # EFI partition — always mounted at /boot
```

Run `lsblk` to confirm. You should see `/mnt`, `/mnt/home`, `/mnt/nix`, `/mnt/boot`, and the other directories all listed as mount points before continuing.

→ [Continue to Step 9 — Create the Swapfile](#step-9--create-the-swapfile)

---

### Step 8b — With LUKS

[↑ Step 8](#step-8--mount-everything)

The process is identical to the non-LUKS path, except the device source is `/dev/mapper/cryptroot` — the open LUKS container — instead of the raw labeled partition. BTRFS and NixOS don't know the difference; from their perspective it's just a block device with a BTRFS filesystem on it.

```bash
mount -o subvol=@,compress=zstd:1,noatime           /dev/mapper/cryptroot /mnt   # root subvolume first — /mnt must exist before subdirs

mkdir -p /mnt/{boot,home,nix,var/log,var/cache,.snapshots,swap}                   # create all mount point directories in one shot

mount -o subvol=@home,compress=zstd:1,noatime        /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,compress=zstd:1,noatime         /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log,compress=zstd:1,noatime         /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@cache,compress=zstd:1,noatime       /dev/mapper/cryptroot /mnt/var/cache
mount -o subvol=@snapshots,compress=zstd:1,noatime   /dev/mapper/cryptroot /mnt/.snapshots
mount -o subvol=@swap,noatime                        /dev/mapper/cryptroot /mnt/swap   # no compression — swapfile requires this

mount /dev/disk/by-label/EFI /mnt/boot   # EFI is never encrypted — mount it directly from the labeled partition
```

Run `lsblk` to confirm all mount points are in place before continuing.

→ [Continue to Step 9 — Create the Swapfile](#step-9--create-the-swapfile)

---

## Step 9 — Create the Swapfile

[↑ Step 8](#step-8--mount-everything)

Swap gives the kernel somewhere to move memory pages when RAM is full, and it is required for hibernation to work. We use a swapfile rather than a dedicated swap partition — it is easier to resize later, and BTRFS fully supports it since kernel 5.0.

The `@swap` subvolume was created without compression specifically for this: BTRFS cannot host a swapfile on a compressed subvolume, and the kernel will refuse to activate it. The `btrfs filesystem mkswapfile` command handles all the details — it creates the file with the correct no-copy-on-write attributes already set, which is a requirement BTRFS enforces strictly.

```bash
btrfs filesystem mkswapfile --size 16G /mnt/swap/swapfile   # create a 16G swapfile with correct BTRFS attributes
swapon /mnt/swap/swapfile                                    # activate it for the current live session
```

> **Size guide:** 16G works well for machines with 16–32G RAM. If you want hibernation to work reliably, the swapfile should be at least as large as your installed RAM. For a machine with 64G RAM, use `--size 64G`.

→ [Continue to Step 10 — Clone the Config](#step-10--clone-the-config)

---

## Step 10 — Clone the Config

[↑ Step 9](#step-9--create-the-swapfile)

The NixOS configuration lives in `~/nixos-config` under the primary user's home directory. We clone it directly to its permanent home inside `/mnt/home/$NIXUSER/` rather than putting it in `/etc/nixos` — that way it's already in the right place after first boot, under version control, and editable like a normal git repo. We then create a symlink at `/mnt/etc/nixos` pointing to it so `nixos-rebuild` and other NixOS tools find it where they expect.

The SSH agent forwarding from Step 3 is what makes `git clone` work here. No GitHub credentials are stored on the target machine — the authentication request travels back through the SSH connection to your admin machine's key.

First, verify your variables are still set. If your SSH session dropped and you reconnected, they will be gone:

```bash
echo "Disk: $DISK  |  Host: $HOST  |  User: $NIXUSER"   # all three must show values — blank means re-export before continuing
```

```bash
mkdir -p /mnt/home/$NIXUSER                                                              # create the user's home directory in the new system

git clone git@github.com:linuxury/nixos-config.git /mnt/home/$NIXUSER/nixos-config      # clone — agent forwarding handles GitHub auth transparently

chown -R 1000:100 /mnt/home/$NIXUSER/nixos-config   # git ran as root; hand ownership to UID 1000 / GID 100 (the "users" group)

mkdir -p /mnt/etc
ln -sf /home/$NIXUSER/nixos-config /mnt/etc/nixos   # symlink /etc/nixos → the config so NixOS tooling finds it

ls -la /mnt/etc/nixos                                # verify the symlink points where expected before moving on
```

→ [Continue to Step 11 — Generate Hardware Config](#step-11--generate-hardware-config)

---

## Step 11 — Generate Hardware Config

[↑ Step 10](#step-10--clone-the-config)

NixOS needs a hardware configuration file specific to this machine — which filesystems it has, which kernel modules to load at boot, what CPU and storage features are available. The `nixos-generate-config` command detects all of this and produces a ready-to-use Nix file.

We use `--show-hardware-config` to print the output to stdout instead of writing it directly, then redirect it into the correct location inside the flake. This writes it straight to the host's directory in the config repo, exactly where the flake expects to find it.

```bash
nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/home/$NIXUSER/nixos-config/hosts/$HOST/hardware-configuration.nix
```

Review the generated file before continuing:

```bash
cat /mnt/home/$NIXUSER/nixos-config/hosts/$HOST/hardware-configuration.nix
```

Check that the BTRFS subvolumes (`@`, `@home`, `@nix`, etc.) appear in the filesystems section with the correct mount points and options. If you installed with LUKS, confirm there is a `boot.initrd.luks.devices` section — if that section is missing, check `hosts/ThinkPad/default.nix` for a working reference and add it manually before proceeding.

→ [Continue to Step 12 — Install](#step-12--install)

---

## Step 12 — Install

[↑ Step 11](#step-11--generate-hardware-config)

This is the step that builds and installs the actual system. `nixos-install` reads your flake, resolves every package and configuration option defined for this host, downloads what isn't already cached, builds everything, and writes the result to `/mnt`. The first install takes the longest — you're downloading and building from a cold cache. Subsequent installs on the same machine are much faster.

`--no-root-passwd` skips the interactive root password prompt at the end. You don't need a root password — the user account you'll set up in the next step is what you use to log in, and `sudo` is configured declaratively in the flake.

```bash
nixos-install \
  --flake /mnt/home/$NIXUSER/nixos-config#$HOST \
  --no-root-passwd
```

You will see a lot of output as packages download and build — that is normal. Warnings about locale or missing optional files during activation are generally harmless. If the command exits with an error, scroll up past the activation output to find the actual build failure — it typically appears well before the end of the output.

→ [Continue to Step 13 — Set the User Password](#step-13--set-the-user-password)

---

## Step 13 — Set the User Password

[↑ Step 12](#step-12--install)

> ⚠️ **Do not skip this step.** The user account was created by the install but it has a locked password. If you reboot without setting it here, you will not be able to log in — and you will have to boot the ISO again just to reach this point.

`nixos-enter` runs a single command inside the installed system's chroot and exits automatically when it finishes. It is the correct way to interact with the new system before rebooting into it — it gives the command the correct environment, correct paths, and correct PAM configuration of the installed system rather than the live ISO.

```bash
echo "Setting password for: $NIXUSER"        # final check that the variable is correct
nixos-enter --root /mnt -- passwd $NIXUSER   # enter the new system's chroot and set the user password
```

It will prompt for the new password twice, then return you to the ISO shell automatically.

→ [Continue to Step 14 — Reboot](#step-14--reboot)

---

## Step 14 — Reboot

[↑ Step 13](#step-13--set-the-user-password)

Unmount everything cleanly before rebooting. `swapoff` first so the kernel stops using the swapfile, then `umount -R` which recursively unmounts all the subvolume mounts under `/mnt` in dependency order — no need to unmount each one individually.

```bash
swapoff -a      # deactivate the swapfile before unmounting
umount -R /mnt  # recursively unmount all mounts under /mnt in the correct order
reboot
```

Remove the USB drive when the machine powers off. On the next boot:
- **Without LUKS** — the system boots straight to the login screen
- **With LUKS** — the system pauses before loading the OS and prompts for your passphrase

→ [Continue to After First Boot](#after-first-boot)

---

## After First Boot

[↑ Step 14](#step-14--reboot)

The system is installed and running your flake config. Continue with **[02-first-boot.md](02-first-boot.md)** which covers everything that needs to happen after the first login:

- Connect to Tailscale
- Generate the machine's SSH key and register it on GitHub
- Register the machine in `secrets/secrets.nix` and re-key agenix so it can decrypt its own secrets
- Clone wallpapers and other assets
- Any host-specific manual steps

---

## Reinstalling an Existing Host

[↑ Back to Contents](#-contents)

A reinstall wipes the disk and generates a new SSH host key. Two things need handling: backing up the personal SSH key before the wipe so you don't have to re-register it with agenix, and updating the host key in `secrets/secrets.nix` after the reinstall since it always regenerates on a fresh install.

### Before Formatting — Back Up the Personal Key

Run this on your admin machine before you wipe anything. If you have this backup, you can restore the same key after reinstall and skip updating the personal key in `secrets.nix`:

```bash
scp <hostname>:~/.ssh/id_ed25519     ~/backup-<hostname>-key      # back up the private key
scp <hostname>:~/.ssh/id_ed25519.pub ~/backup-<hostname>-key.pub   # back up the public key
```

### After Reinstall — Update the Host Key in secrets.nix

The SSH host key always regenerates on a fresh install. Once the reinstalled machine is back online, collect the new host key from your admin machine:

```bash
ssh-keyscan -t ed25519 <hostname> | awk '{print $3}'   # prints the new host public key — copy this
```

Paste it into `secrets/secrets.nix` next to `<hostname>`, replacing the old value. Then re-key all secrets so the new host key is added as a recipient and can decrypt on future rebuilds:

```bash
cd ~/nixos-config
age-rekey                                                    # re-encrypt all secrets with the updated recipient list
git add secrets/
git commit -m "update <hostname> host key after reinstall"
git push
```

Pull and rebuild on the reinstalled machine to pick up the updated secrets:

```bash
ssh <user>@<hostname> "cd ~/nixos-config && git pull && nr"
```

### After Reinstall — Restore the Personal Key

If you backed it up before the format, restore it and fix permissions:

```bash
scp ~/backup-<hostname>-key     <hostname>:~/.ssh/id_ed25519      # restore private key
scp ~/backup-<hostname>-key.pub <hostname>:~/.ssh/id_ed25519.pub   # restore public key
ssh <hostname> "chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub"   # private key must not be world-readable
ssh -T git@github.com           # verify GitHub still accepts the restored key
```

---

## Common Problems

[↑ Back to Contents](#-contents)

| Problem | Fix |
|---------|-----|
| `git clone` fails: "Permission denied (publickey)" | Run `ssh-add ~/.ssh/id_ed25519` on your admin machine, then reconnect with `ssh -A root@<ip>` |
| `nixos-install` fails: "flake does not provide attribute" | `$HOST` must match `flake.nix` exactly — it's case-sensitive (`ThinkPad` not `thinkpad`) |
| `echo $HOST` shows nothing | SSH session dropped and variables were lost — re-export all three before continuing |
| LUKS: boot hangs at passphrase prompt, keyboard does nothing | Add `boot.initrd.availableKernelModules = ["usbhid" "xhci_pci"]` to the host's NixOS config |
| System boots to emergency shell | Run `journalctl -b` — usually a subvolume mount option mismatch in the generated hardware config |
| Can't log in after first boot | Password wasn't set — boot the ISO again and run `nixos-enter --root /mnt -- passwd $NIXUSER` |
| LUKS: `cryptsetup open` succeeds but system won't find the device | Confirm `boot.initrd.luks.devices` is in the hardware config — check `hosts/ThinkPad/default.nix` for reference |
