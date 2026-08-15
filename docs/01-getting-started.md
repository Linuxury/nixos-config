# Getting Started

This page covers everything you need to do before touching a disk — what this config is, which install guide applies to your machine, how to get the NixOS ISO, how to put it on a USB drive, and how to boot into it. Every installation type starts here.

---

## Contents

- [What is NixOS?](#what-is-nixos)
- [What is this Config?](#what-is-this-config)
- [Which Guide Is for You?](#which-guide-is-for-you)
- [Step 1 — Download the ISO](#step-1--download-the-iso)
- [Step 2 — Flash the ISO to USB](#step-2--flash-the-iso-to-usb)
  - [Option A — Ventoy (recommended for repeated use)](#option-a--ventoy-recommended-for-repeated-use)
  - [Option B — Balena Etcher (easiest one-shot)](#option-b--balena-etcher-easiest-one-shot)
  - [Option C — Rufus (Windows)](#option-c--rufus-windows)
  - [Option D — Terminal with dd (Linux / macOS)](#option-d--terminal-with-dd-linux--macos)
- [Step 3 — Boot from the USB](#step-3--boot-from-the-usb)
- [Step 4 — First Things in the Installer](#step-4--first-things-in-the-installer)
- [Common Problems: `dd` Fails Partway Through, Every Time](#common-problems-dd-fails-partway-through-every-time)
- [You're Ready](#youre-ready)

---

## What is NixOS?

NixOS is a Linux distribution built around one idea: **the entire system is declared in code**. Instead of installing packages and editing config files manually — and then forgetting what you changed six months later — NixOS keeps the complete description of the system in a set of `.nix` files checked into version control. Want a package? Add it to the config. Want to undo a change? Roll back to the previous generation. Want to reproduce the exact same system on a different machine? Point it at the same config and rebuild.

A few things that make NixOS different from other distros:

- **Declarative** — you describe what the system should look like, not what commands to run to get there
- **Atomic upgrades** — updates either fully succeed or the system stays exactly as it was; no half-upgraded states
- **Generations** — every rebuild creates a new generation; booting the previous one is a GRUB menu option away
- **Flakes** — a standardized way to pin all inputs (packages, modules, dependencies) to exact versions so builds are reproducible across machines and time

---

## What is this Config?

This is a family NixOS setup built for a 3-person household — covering 6 desktops and laptops and 3 headless servers. Everything is version-controlled: disk layout, desktop environment, applications, secrets, theming, and services.

**Highlights:**

- **COSMIC DE** on all graphical machines (System76's Rust-based desktop)
- **Hyprland** on linuxury's machines (tiling Wayland compositor)
- **BTRFS** on every host — `@`, `@home`, `@nix`, `@log`, `@cache`, `@snapshots`, and `@swap` subvolumes
- **Automatic snapshots** via Snapper — hourly, daily, and weekly on `/` and `/home`
- **matugen theming** — wallpaper-driven color pipeline; terminal, editor, and desktop all sync automatically
- **ragenix secrets** — SSH keys, WireGuard configs, and service passwords encrypted in the repo; no plaintext ever committed
- **Tailscale mesh** — every machine reachable by hostname from anywhere
- **Family Samba shares** — network drives auto-mounted on all desktops
- **Gaming** — Steam, MangoHud, GameMode, Proton on all gaming machines
- **Media server** — Plex, Sonarr, Radarr, Prowlarr, Immich, FreshRSS on dedicated hardware

**Hosts at a glance:**

| Host | User | Role |
|------|------|------|
| ThinkPad | linuxury | Laptop |
| Ryzen5900x | linuxury | Desktop |
| Ryzen5800x | babylinux | Desktop |
| Asus-A15 | babylinux | Laptop |
| Alex-Desktop | alex | Kid's desktop |
| Alex-Laptop | alex | Kid's laptop |
| Media-Server | — | Plex · Arr stack · Immich · FreshRSS |
| Radxa-X4 | — | Torrent (Mullvad VPN killswitch) |
| MinisForum | — | Game servers (Minecraft · Hytale) |

---

## Which Guide Is for You?

There are four installation guides — pick the one that matches your machine:

| Guide | Boot type | Encryption | Hosts |
|-------|-----------|------------|-------|
| [02-install-uefi.md](02-install-uefi.md) | UEFI | None | Ryzen5900x, Ryzen5800x, Alex-Laptop, Media-Server, Radxa-X4, MinisForum |
| [03-install-luks.md](03-install-luks.md) | UEFI | LUKS full-disk | ThinkPad, Asus-A15 |
| [04-install-legacy-bios.md](04-install-legacy-bios.md) | Legacy BIOS | None | Alex-Desktop |
| [05-install-legacy-luks.md](05-install-legacy-luks.md) | Legacy BIOS | LUKS full-disk | — (edge case, available if needed) |

**Not sure which boot type your machine uses?** Most machines bought after 2012 are UEFI. Alex-Desktop is the exception — it uses Legacy BIOS. If you're unsure, check the machine's firmware settings screen: if you see "UEFI" in the menu name or there is a Secure Boot setting, it's UEFI. If the screen looks old and text-only with no Secure Boot option, it is likely Legacy BIOS.

**LUKS** encrypts the entire disk with a passphrase. Without it, anyone who removes the drive and puts it in another machine can read everything. With LUKS, they get an encrypted blob — useless without the passphrase. The tradeoff is entering that passphrase on every boot. Laptops that leave the house get LUKS; desktops and servers that stay put do not.

---

## Step 1 — Download the ISO

Download the **NixOS minimal ISO** from the official site.

Go to **[nixos.org/download](https://nixos.org/download)** and select:
- **NixOS** (not Home Manager, not nix-darwin)
- Architecture: **x86_64 Linux**
- Image: **Minimal ISO image**

Do not use the graphical installer ISO. The graphical installer is a separate product with its own partitioning UI. This guide uses the minimal shell environment where you have full control over partitioning from the command line.

The minimal ISO is around 800 MB. Verify the SHA-256 hash if you want to confirm the download is intact — the hash is listed next to the download link on the NixOS site.

---

## Step 2 — Flash the ISO to USB

You need a USB drive of **at least 4 GB**. The flash process will erase everything on the USB drive, so back up anything on it first.

Four methods are covered below — pick whichever fits your situation.

---

### Option A — Ventoy (recommended for repeated use)

Ventoy turns the USB into a multi-boot drive. You install Ventoy to the USB once, then just copy ISO files onto it. No reflashing needed when you download a new ISO version — just copy and replace.

**Install Ventoy to the USB:**

On Linux:
```bash
# Download from ventoy.net, extract the archive, then:
sudo bash Ventoy2Disk.sh -i /dev/sdX   # replace /dev/sdX with your USB device
```

On Windows: download `Ventoy2Disk.exe` from ventoy.net, launch it, select your USB, click Install.

**Copy the ISO:**
```bash
cp nixos-minimal-*.iso /media/yourUSBdrive/   # copy the ISO to the Ventoy partition
```

Or just drag the ISO file into the USB drive in your file manager. When you boot from the USB, Ventoy presents a menu and you select the ISO.

---

### Option B — Balena Etcher (easiest one-shot)

Etcher is a GUI tool that makes this as simple as it gets. Download it from **balena.io/etcher** — available for Linux, macOS, and Windows.

1. Open Etcher
2. Click **Flash from file** → select the NixOS ISO
3. Click **Select target** → select your USB drive (Etcher only shows removable drives, reducing the risk of picking the wrong device)
4. Click **Flash** and wait — it verifies the write automatically when done

---

### Option C — Rufus (Windows)

Rufus is the standard tool for creating bootable USB drives on Windows. Download from **rufus.ie**.

1. Open Rufus
2. Under **Device**, select your USB drive
3. Under **Boot selection**, click **SELECT** and pick the NixOS ISO
4. Leave everything else at defaults — Rufus will detect the correct settings from the ISO
5. Click **START** and confirm when it warns about erasing the drive

---

### Option D — Terminal with dd (Linux / macOS)

`dd` is the fastest method and works on any Linux or macOS machine without installing anything. It is also the most dangerous if you pick the wrong device — it will silently erase whatever you point it at without asking again.

**First — identify your USB device with lsblk (Linux) or diskutil (macOS). Do not skip this.**

On Linux:
```bash
lsblk                                 # look for your USB by size — it will be something like /dev/sdb or /dev/sdc
```

On macOS:
```bash
diskutil list                         # look for your USB — it will be something like /disk2 or /disk3
```

**Then flash:**

On Linux:
```bash
sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress conv=fsync   # replace /dev/sdX — do not add a partition number
```

On macOS:
```bash
sudo dd if=nixos-minimal-*.iso of=/dev/rdiskX bs=4m                           # use /dev/rdisk (raw) for significantly faster write speed
```

`conv=fsync` (Linux) ensures all data is fully written to the device before `dd` returns. On macOS the equivalent is to run `sync` after `dd` finishes. Wait for the command to fully complete and return you to a prompt before removing the USB.

---

## Step 3 — Boot from the USB

Power off the target machine if it is running. Plug in the USB drive.

**Access the boot menu or firmware settings.** The key you press depends on the manufacturer — press it repeatedly immediately after powering on, before the OS starts loading:

| Manufacturer | BIOS / UEFI settings | One-time boot menu |
|-------------|----------------------|--------------------|
| Lenovo / ThinkPad | F1 | F12 |
| Dell | F2 | F12 |
| HP | F10 | F9 |
| ASUS | F2 | F8 |
| MSI | Delete | F11 |
| Gigabyte | Delete or F2 | F12 |
| ASRock | F2 | F11 |

If you miss the window, the machine boots normally — just power it off and try again.

**Disable Secure Boot.** The NixOS minimal ISO does not support Secure Boot by default. If the machine has Secure Boot enabled (common on UEFI machines), the USB will be rejected at boot. To disable it:

1. Enter firmware settings (the first key in the table above)
2. Look for a **Security** or **Boot** section
3. Find **Secure Boot** and set it to **Disabled**
4. Save and exit — the machine will restart

**Select the USB from the boot menu.** Use the one-time boot menu key (the second column in the table) to get a menu listing all bootable devices. Select your USB drive — it may be listed as the ISO name, the USB brand, or as "USB HDD". If you see a Ventoy menu, select the NixOS ISO from the list.

If no boot menu key works, you can set boot order inside the firmware settings: find the **Boot Order** or **Boot Priority** section and move the USB device to first position, then save and exit.

---

## Step 4 — First Things in the Installer

The NixOS installer boots to a shell and logs in automatically as `nixos` — no password required. You will see a console prompt like:

```
[nixos@nixos:~]$
```

**Make the text readable.** The default console font is very small on modern high-resolution monitors. Set a larger font before doing anything else:

```bash
setfont ter-118b   # much larger font — makes the rest of the install significantly easier to read
```

**Confirm the machine booted in the right mode.** Check whether it booted as UEFI or Legacy BIOS — this must match the guide you are following:

```bash
ls /sys/firmware/efi   # if this directory exists: UEFI boot confirmed
                       # if "No such file or directory": Legacy BIOS boot confirmed
```

If the result does not match your expected boot mode, go back into the firmware settings and check that Secure Boot is off and that the boot mode (sometimes labeled "CSM" or "Legacy Boot") is configured correctly.

---

## Common Problems: `dd` Fails Partway Through, Every Time

If flashing the ISO fails repeatedly at the same byte offset — same error, same position, no matter how many times you retry — there are two distinct causes that produce nearly identical symptoms. Telling them apart matters, because the fix is completely different: one means retire the drive, the other means stop blaming the drive.

**Symptoms common to both causes:**

- `dd` fails with `No space left on device` at the same byte offset on every retry, regardless of block size or flags (`oflag=direct` included)
- `dd`'s reported write speed is implausibly fast (multiple GB/s) — no USB flash drive writes anywhere near that fast; a near-instant "success" followed by an immediate error means the write was rejected before real hardware I/O happened, not that a slow physical write was attempted and failed
- `sudo dmesg | tail -60` shows no corresponding I/O error or USB disconnect event around the failure
- `wipefs -a`, `blockdev --rereadpt`, unplugging/replugging, and switching ports/cables all change nothing

**The fastest way to tell them apart: try a completely different physical machine.** Not a different port on the same machine — an entirely different computer. This is faster and more conclusive than any of the tests below, and should be the *first* thing you reach for once a retry-with-different-flags hasn't fixed it:

- **Works cleanly on a different machine** → the original host has a USB controller/driver-level fault (bad xHCI controller, a marginal port, or a kernel/hardware quirk specific to that machine). The drive is fine. This kind of fault can reproduce identically across multiple different drives on the same host — including landing on the exact same byte offset every time — because the failure happens below the level `dmesg` normally logs, which is what makes it look so much like a bad drive. Worth flagging the host itself for a closer look (check other USB ports, consider a different port/hub, watch for the same behavior with unrelated USB peripherals later).
- **Fails the same way everywhere** → now it's worth suspecting the drive. Counterfeit USB flash drives are common on marketplace listings — firmware reports a large capacity (128GB, 1TB, whatever sounds appealing) while the real NAND behind it is a tiny fraction of that, often 1-2GB. Confirm with a targeted write past the failure point:

  ```bash
  # Replace /dev/sdX with your drive. This targets an offset (2GB here)
  # comfortably past whatever byte offset the ISO write failed at.
  echo "test-marker" | sudo dd of=/dev/sdX bs=1M seek=2000 conv=fsync
  ```

  If this tiny write fails immediately with `No space left on device` **on more than one machine**, the drive's real capacity is below that offset. For conclusive proof (worth doing before buying more from the same seller), use `f3probe`:

  ```bash
  nix-shell -p f3 --run "sudo f3probe --destructive --time-ops /dev/sdX"
  ```

**Don't declare a drive counterfeit on the strength of same-host testing alone** — a same-byte-offset failure across multiple drives feels like damning proof of fake capacity, but it's exactly what a host-side fault produces too. Cross-machine confirmation is what actually distinguishes them.

---

## You're Ready

You are now at the `nixos` shell on the target machine with the installer running. Continue with the guide for your machine:

| Your machine | Continue with |
|---|---|
| Ryzen5900x, Ryzen5800x, Alex-Laptop, servers | [02-install-uefi.md](02-install-uefi.md) |
| ThinkPad, Asus-A15 | [03-install-luks.md](03-install-luks.md) |
| Alex-Desktop | [04-install-legacy-bios.md](04-install-legacy-bios.md) |
| Legacy BIOS + encryption (edge case) | [05-install-legacy-luks.md](05-install-legacy-luks.md) |

Each guide picks up exactly from this point — no repeated setup, straight into partitioning.
