# Install — UEFI + LUKS (Full-Disk Encryption)

This guide installs NixOS on a UEFI machine with full-disk encryption via LUKS. It applies to:

| Host | User |
|------|------|
| ThinkPad | linuxury |
| Asus-A15 | babylinux |

**Before starting:** complete [getting-started.md](getting-started.md) — you should be at the `nixos` shell with the installer running and the console font set.

---

## What LUKS Does

LUKS (Linux Unified Key Setup) encrypts the entire main partition with a passphrase. When the machine boots, it stops before loading the OS and asks for that passphrase. If the correct passphrase is entered, it decrypts the container and continues booting normally. If the drive is removed and put in another machine without the passphrase, the contents are completely unreadable — just encrypted data.

The EFI partition (bootloader) is never encrypted — the firmware needs to read it before any passphrase can be entered. Only the main partition goes into LUKS. BTRFS and NixOS sit inside the encrypted container and are transparent to it — they see a normal block device and do not know or care that it is encrypted underneath.

The tradeoff is typing your passphrase on every boot. Write it down somewhere safe before the install — there is no recovery mechanism. If you forget it, the data on the drive is gone permanently.

---

## Contents

- [Step 1 — Connect to the Network](#step-1--connect-to-the-network)
- [Step 2 — Enable SSH and Connect from Your Admin Machine](#step-2--enable-ssh-and-connect-from-your-admin-machine)
- [Step 3 — Identify Your Disk and Set Variables](#step-3--identify-your-disk-and-set-variables)
- [Step 4 — Partition the Disk](#step-4--partition-the-disk)
- [Step 5 — Set Up LUKS and Format the Partitions](#step-5--set-up-luks-and-format-the-partitions)
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
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:0    0 476.9G  0 disk         ← NVMe SSD — likely your target
sda           8:0    0   1.8T  0 disk         ← external drive — do not touch
```

Disk naming follows the hardware type. NVMe and eMMC drives use a `p` before the partition number; SATA drives do not:

| Drive type | Disk name | Partition 1 | Partition 2 |
|-----------|-----------|-------------|-------------|
| NVMe SSD | `/dev/nvme0n1` | `nvme0n1p1` | `nvme0n1p2` |
| SATA SSD/HDD | `/dev/sda` | `sda1` | `sda2` |
| eMMC | `/dev/mmcblk0` | `mmcblk0p1` | `mmcblk0p2` |

> Double-check the disk name and size before moving on. The next step permanently erases everything on the selected disk.

Set the three variables that drive every command from here forward. Set them once and every code block is copy-pasteable without editing:

```bash
export DISK=/dev/nvme0n1   # your actual disk — replace this value
export HOST=ThinkPad       # your host name — capitalization must be exact
export NIXUSER=linuxury    # the primary user for this host
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
| `ThinkPad` | `linuxury` | linuxury's laptop | this guide |
| `Ryzen5900x` | `linuxury` | linuxury's desktop | [uefi.md](uefi.md) |
| `Ryzen5800x` | `babylinux` | Milagros' desktop | [uefi.md](uefi.md) |
| `Asus-A15` | `babylinux` | Milagros' laptop | this guide |
| `Alex-Desktop` | `alex` | Alex's desktop | [legacy-bios.md](legacy-bios.md) |
| `Alex-Laptop` | `alex` | Alex's laptop | [uefi.md](uefi.md) |
| `Media-Server` | `linuxury` | Media server | [uefi.md](uefi.md) |
| `Radxa-X4` | `linuxury` | Torrent server | [uefi.md](uefi.md) |
| `MinisForum` | `linuxury` | Game server | [uefi.md](uefi.md) |

---

## Step 4 — Partition the Disk

This creates two partitions. The layout is the same with or without LUKS — LUKS wraps the filesystem inside a partition and does not change the partition structure itself.

The first partition (512 MiB) holds the bootloader — this is the EFI System Partition (ESP), required for UEFI boot, and it is never encrypted. The second partition takes all remaining space. LUKS will wrap this partition, and BTRFS will live inside the LUKS container.

```bash
wipefs -a $DISK                                   # wipe any existing signatures from the disk

parted $DISK -- mklabel gpt                       # create a fresh GPT partition table
parted $DISK -- mkpart EFI fat32 1MiB 513MiB      # 512 MiB EFI partition — always unencrypted
parted $DISK -- set 1 esp on                      # mark partition 1 as the EFI System Partition
parted $DISK -- mkpart primary 513MiB 100%        # main partition — LUKS goes here
```

After this you have two partitions: `${DISK}${P}1` for EFI and `${DISK}${P}2` for the encrypted main system.

---

## Step 5 — Set Up LUKS and Format the Partitions

The EFI partition gets FAT32 as always. The main partition gets wrapped in a LUKS container before BTRFS is placed inside it.

When `cryptsetup luksFormat` runs it will ask:

```
Are you sure? (Type 'YES' in capital letters):
```

Type `YES` in all caps exactly as shown, then enter and confirm your passphrase. **Write the passphrase down before running this block — there is no recovery mechanism.**

After `cryptsetup open`, the decrypted container is available at `/dev/mapper/cryptroot`. All remaining work happens there. BTRFS and NixOS see a normal block device — they do not know it is encrypted underneath.

```bash
mkfs.fat -F 32 -n EFI ${DISK}${P}1                    # FAT32 with label "EFI" — always unencrypted

cryptsetup luksFormat --label nixos-luks ${DISK}${P}2  # creates the encrypted container — prompts for a passphrase
cryptsetup open ${DISK}${P}2 cryptroot                 # decrypts and exposes the container as /dev/mapper/cryptroot

mkfs.btrfs -f -L nixos /dev/mapper/cryptroot           # BTRFS goes inside the container, not directly on the partition
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

Mount the BTRFS filesystem inside the open LUKS container temporarily to create the subvolumes, then unmount:

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

Each subvolume gets mounted at its permanent location under `/mnt` with the correct options. The source device is `/dev/mapper/cryptroot` — the open LUKS container — instead of the labeled partition. BTRFS and NixOS do not know the difference; from their perspective it is just a block device with a BTRFS filesystem on it.

Two mount options apply to every subvolume except swap:

- **`compress=zstd:1`** — transparent compression at level 1. Fast, saves meaningful space (especially on the Nix store which is full of text-heavy files). The OS and apps never see this — files are compressed on disk and decompressed transparently on read.
- **`noatime`** — don't update the "last accessed" timestamp every time a file is read. A significant performance improvement on SSDs with no real downside.

The swap subvolume deliberately omits `compress` — BTRFS cannot host a swapfile on a compressed subvolume and the kernel will refuse to activate it.

```bash
mount -o subvol=@,compress=zstd:1,noatime           /dev/mapper/cryptroot /mnt   # root subvolume first

mkdir -p /mnt/{boot,home,nix,var/log,var/cache,.snapshots,swap}                   # all mount point dirs in one shot

mount -o subvol=@home,compress=zstd:1,noatime        /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,compress=zstd:1,noatime         /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log,compress=zstd:1,noatime         /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@cache,compress=zstd:1,noatime       /dev/mapper/cryptroot /mnt/var/cache
mount -o subvol=@snapshots,compress=zstd:1,noatime   /dev/mapper/cryptroot /mnt/.snapshots
mount -o subvol=@swap,noatime                        /dev/mapper/cryptroot /mnt/swap   # no compression — swapfile requires this

mount /dev/disk/by-label/EFI /mnt/boot   # EFI is never encrypted — mount it directly from the labeled partition
```

Run `lsblk` to confirm. You should see `/mnt`, `/mnt/home`, `/mnt/nix`, `/mnt/boot`, and the other directories all listed as mount points before continuing.

---

## Step 8 — Create the Swapfile

Swap gives the kernel somewhere to move memory pages when RAM is full, and it is required for hibernation. We use a swapfile rather than a dedicated swap partition — easier to resize later, and BTRFS fully supports it since kernel 5.0.

The `@swap` subvolume was created without compression specifically for this: BTRFS cannot host a swapfile on a compressed subvolume, and the kernel will refuse to activate it. `btrfs filesystem mkswapfile` creates the file with the correct no-copy-on-write attributes already set.

```bash
btrfs filesystem mkswapfile --size 16G /mnt/swap/swapfile   # create a 16G swapfile with correct BTRFS attributes
swapon /mnt/swap/swapfile                                    # activate it for the current live session
```

> **Size guide:** 16G works well for machines with 16–32G RAM. For hibernation to work reliably, the swapfile should be at least as large as your installed RAM. For a machine with 32G RAM, use `--size 32G`.

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

**LUKS-specific check:** confirm there is a `boot.initrd.luks.devices` section in the file. This tells the initrd to prompt for the passphrase before mounting the root filesystem. If that section is missing, the system will boot into an emergency shell because it cannot find the root device. Check `hosts/ThinkPad/default.nix` for a working reference and add it manually if needed:

```nix
boot.initrd.luks.devices."cryptroot" = {
  device = "/dev/disk/by-label/nixos-luks";
  allowDiscards = true;   # enables TRIM on the encrypted SSD — important for SSD longevity
};
```

Also confirm the BTRFS subvolumes (`@`, `@home`, `@nix`, etc.) appear with the correct mount points and options.

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

Remove the USB drive when the machine powers off. On the next boot the system will pause before loading the OS and prompt for your LUKS passphrase. Enter it and the system continues booting normally.

---

## After First Boot

The system is installed and running your flake config. Continue with **[02-first-boot.md](../02-first-boot.md)** which covers:

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
| `git clone` fails: "Permission denied (publickey)" | Run `ssh-add ~/.ssh/id_ed25519` on your admin machine, then reconnect with `ssh -A root@<ip>` |
| `nixos-install` fails: "flake does not provide attribute" | `$HOST` must match `flake.nix` exactly — it is case-sensitive (`ThinkPad` not `thinkpad`) |
| `echo $HOST` shows nothing | SSH session dropped and variables were lost — re-export all three before continuing |
| Boot hangs at passphrase prompt, keyboard does nothing | Add `boot.initrd.availableKernelModules = ["usbhid" "xhci_pci"]` to the host's NixOS config |
| `cryptsetup open` succeeds but system won't find the device at boot | Confirm `boot.initrd.luks.devices` is in the hardware config — check `hosts/ThinkPad/default.nix` for reference |
| System boots to emergency shell | Run `journalctl -b` — usually a missing LUKS block or subvolume mount option mismatch |
| Can't log in after first boot | Password wasn't set — boot the ISO again and run `nixos-enter --root /mnt -- passwd $NIXUSER` |
