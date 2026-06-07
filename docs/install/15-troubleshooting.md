# Troubleshooting

Common failures, their causes, and how to fix them. Organized by area. For deeper context on any topic, the relevant doc is linked in the section header.

---

## Contents

- [Rebuild / nixos-rebuild](#rebuild--nixos-rebuild)
- [Secrets / ragenix](#secrets--ragenix)
- [Network / Tailscale / Samba](#network--tailscale--samba)
- [Theming / matugen](#theming--matugen)
- [COSMIC / Desktop](#cosmic--desktop)
- [Hyprland](#hyprland)
- [KDE / Desktop](#kde--desktop)
- [Gaming](#gaming)
- [Servers](#servers)
- [SSH](#ssh)
- [Disk / Storage](#disk--storage)
- [General Debugging](#general-debugging)

---

## Rebuild / nixos-rebuild

See [07-flake-guide.md](07-flake-guide.md) for the full config structure reference.

### error: flake does not provide attribute

The hostname passed to `--flake .#<HostName>` doesn't match any entry in `flake.nix`. Host names are case-sensitive — `ThinkPad` works, `thinkpad` does not. Check the exact names:

```bash
grep -A1 "mkHost" ~/nixos-config/flake.nix | grep hostname   # prints all valid host names
```

---

### Rebuild fails with hash mismatch or fixed-output derivation error

A Nix fetch got a different file than expected — remote content changed or a network error returned partial data. Refresh the lock file and rebuild:

```bash
nix flake update   # refresh lock file with current upstream commits
nr                 # rebuild with updated inputs
```

---

### warning: Git tree is dirty — build ignores my changes

Nix flakes only see **committed** files. Untracked or uncommitted changes are invisible to the build system. Stage and commit first, then rebuild:

```bash
git add -A && git commit -m "wip"
nr
```

---

### Home Manager activation fails with checkLinkTargets

A file that Home Manager wants to manage already exists on disk and isn't a symlink from HM. Find the conflicting file named in the error, back it up, then rebuild:

```bash
mv ~/.config/conflicting-file ~/.config/conflicting-file.bak
nr
```

---

### checkLinkTargets fails for ~/.config/gtk-4.0/gtk.css (COSMIC hosts)

libcosmic apps (COSMIC Files, Settings, etc.) write `~/.config/gtk-4.0/gtk.css` on every launch by symlinking it to `cosmic/dark.css`. This clobbers Home Manager's managed file. The config includes a pre-activation cleanup (`home.activation.clearGtkCss`) that removes it before HM's link check — if this triggers after a HM upgrade or clean install, just rebuild:

```bash
rm -f ~/.config/gtk-4.0/gtk.css
nr
```

---

## Secrets / ragenix

See [08-secrets.md](08-secrets.md) for the full secrets workflow.

### agenix: secret cannot be decrypted with any of the given keys

The machine's host key isn't listed as a recipient for this secret in `secrets/secrets.nix`. Add it and re-key:

1. Get the host key: `cat /etc/ssh/ssh_host_ed25519_key.pub`
2. Add it to `secrets.nix` under the appropriate secret's `publicKeys` list
3. Re-key from your admin machine: `age-rekey`
4. Commit, push, and rebuild the target machine

---

### ragenix: identity not found

Your personal private key (`~/.ssh/id_ed25519`) isn't present, isn't readable, or isn't listed in `linuxury-admins` in `secrets.nix`:

```bash
ls -la ~/.ssh/id_ed25519        # key must exist with permissions 600
ssh-add ~/.ssh/id_ed25519       # add to agent if needed
ssh-add -l                      # confirm it's loaded
```

---

### Secret file is empty or zero-length after activation

Decryption failed silently. Most likely the host key isn't in the recipients list — see the first secrets error above:

```bash
journalctl -b | grep agenix        # check for decryption errors in boot log
sudo systemctl status agenix-*     # check agenix service status
```

---

## Network / Tailscale / Samba

### Tailscale is connected but hostname doesn't resolve

DNS propagation may be lagging. Use the IP directly while waiting, or check the current IP:

```bash
sudo tailscale status    # shows all nodes and their Tailscale IPs
ping 100.x.x.x           # use IP directly to test connectivity
```

---

### CIFS mount fails: mount error(13): Permission denied

The Samba password for this user hasn't been set on the server. Also verify the `smb-credentials` secret was decrypted correctly:

```bash
ssh linuxury@Media-Server
sudo smbpasswd -a linuxury                    # set (or reset) the Samba password
sudo cat /run/agenix/smb-credentials          # verify the secret contains username=... and password=...
```

---

### CIFS mount not accessible / times out

The server is likely not reachable or Samba isn't running. Mounts use `nofail _netdev noauto` so they won't block boot — they mount on first access and time out if the server is off:

```bash
ping Media-Server                 # check basic connectivity
ssh linuxury@Media-Server         # verify SSH works
sudo systemctl status samba       # check Samba is running on the server
```

---

## Theming / matugen

See [13-theming.md](13-theming.md) for the full theming pipeline.

### Terminal colors stopped updating when wallpaper changes

Check the color-sync service status, then force a refresh:

```bash
systemctl --user status wallpaper-color-sync              # check service status
journalctl --user -u wallpaper-color-sync -n 50           # view recent logs
rm ~/.local/share/last-matugen-wallpaper                  # clear the feedback-loop prevention cache
systemctl --user restart wallpaper-color-sync             # force a run now
```

---

### COSMIC desktop flashing / cosmic-session restarting in a loop

Likely caused by a corrupted COSMIC config file — often from a manual edit to the wallpaper config. Check session logs for the error:

```bash
journalctl --user -u cosmic-session -n 100 | grep -i "error\|fail\|panic"
```

For the wallpaper config specifically — switch to a TTY (`Ctrl+Alt+F3`), delete the bad config, then re-set the wallpaper through COSMIC Settings after the session recovers:

```bash
rm -rf ~/.config/cosmic/com.system76.CosmicBackground/
systemctl --user restart cosmic-session
```

---

### Terminal has no colors / all-black or all-white

The matugen seed file (`~/.config/kitty/colors.conf`) is missing or empty, and matugen hasn't run yet. Re-run Home Manager activation to recreate it, then force matugen:

```bash
home-manager switch --flake ~/nixos-config#linuxury   # recreate seed files
rm ~/.local/share/last-matugen-wallpaper              # clear cache
systemctl --user restart wallpaper-color-sync         # force matugen to run
```

---

### Hyprland: border colors or terminal colors missing after `nr`

Home Manager activation rewrites the `~/.config/hypr/` symlink, which deletes `colors.lua`. The matugen deduplication stamp still holds the same wallpaper path, so matugen sees "already processed" and skips — leaving `colors.lua` permanently missing until the wallpaper changes.

Fix: clear the stamp and restart matugen manually:

```bash
rm ~/.local/share/last-matugen-processed
systemctl --user restart matugen
```

---

## COSMIC / Desktop

See [14-de-wm.md](14-de-wm.md) for full COSMIC DE documentation.

### COSMIC Files shows wrong or missing network shares

Favorites are written declaratively by Home Manager. Rebuild to apply changes:

```bash
nr
```

To verify what's currently on disk:

```bash
cat ~/.config/cosmic/com.system76.CosmicFiles/v1/favorites
```

Missing paths (e.g. a server that's off) are silently skipped — this is expected, not an error.

---

### Display scaling looks wrong after first boot

COSMIC stores display settings per-monitor by EDID. Open **COSMIC Settings → Displays** and set your preferred scaling — it's remembered for that monitor.

---

## Hyprland

### Login takes ~65 seconds after entering password (Ryzen5900x)

KWin (SDDM's greeter compositor) grabs the DRM device via logind. When seatd is also running, it can never start and hangs for its full 90s timeout — blocking `graphical.target`, which blocks UWSM, which delays Hyprland.

This is already fixed in the config (`services.seatd.enable = lib.mkForce false` + `LIBSEAT_BACKEND=logind`). If the delay reappears after a rebuild, verify these are still set:

```bash
systemctl status seatd          # should be inactive/disabled
echo $LIBSEAT_BACKEND           # should print "logind"
journalctl -b | grep -i seatd   # look for repeated timeout messages
```

If seatd is running, a full rebuild should restore the override.

---

### Hyprland crashes or fails to start after logging out of a KDE session

When Hyprland's libseat auto-detection tries seatd first (the default), and seatd isn't available because KWin already holds the seat via logind, the connection fails repeatedly. The config forces `LIBSEAT_BACKEND=logind` to skip seatd entirely.

If Hyprland fails to start or exits immediately, check:

```bash
journalctl -b | grep -iE "hyprland|libseat|aquamarine"
echo $LIBSEAT_BACKEND   # must be "logind"
```

If `LIBSEAT_BACKEND` is not set, the session environment wasn't applied — rebuild and re-login.

---

### SDDM greeter has no cursor (invisible on login screen)

This was caused by using Weston as the SDDM Wayland compositor. Weston never advertised pointer capability (`wl_seat.capabilities`) to Qt for keyboard dongle devices (Keychron Ultra-Link, Lemokey Link), so Qt never created a `wl_pointer` object — no cursor regardless of any theme or env var.

The fix (already in config): SDDM uses KWin as its compositor (`services.displayManager.sddm.wayland.compositor = "kwin"`). If the cursor disappears again after a rebuild, confirm this is still set:

```bash
grep -r "compositor" /etc/sddm.conf.d/   # should show kwin, not weston
```

---

## KDE / Desktop

### SDDM login screen reverts to Breeze theme after opening System Settings

Opening **System Settings → Login Screen** causes `sddm-kcm` to write `/etc/sddm.conf.d/kde_settings.conf` containing `[Theme] Current=breeze`. This file sorts after `00-nixos.conf` and overrides the declarative theme on every boot.

The config includes an activation script that deletes this file on every rebuild. If the theme reverts, rebuild to clean it up:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#Ryzen5800x   # or Asus-A15
```

Do not use **System Settings → Login Screen** to change the SDDM theme — configure it declaratively in `greeters/sddm/default.nix` instead.

---

## Gaming

See [12-gaming.md](12-gaming.md) for full gaming setup documentation.

### Steam game won't launch

1. Try Proton-GE instead of default Proton (or switch back if already using GE)
2. Add `PROTON_LOG=1 %command%` to launch options — check `~/.steam/steam/logs/`
3. Open the Steam console at `steam://open/console` for more detailed error output

---

### MangoHud overlay not appearing

Some anti-cheat games block overlays entirely. For others, verify the installation and launch option:

```bash
which mangohud   # verify MangoHud is installed and in PATH
```

Confirm the launch option is exactly `MANGOHUD=1 %command%` — it is case-sensitive.

---

### Asus-A15 using iGPU instead of dGPU

Add to Steam launch options and verify the PCI bus IDs in `hosts/Asus-A15/default.nix` are correct for this machine (`lspci | grep -E "VGA|3D"`):

```
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia %command%
```

---

## Servers

See [10-servers.md](10-servers.md) for full server management documentation.

### Server service is failed

```bash
systemctl --failed                     # list all currently failed services
journalctl -u <service-name> -n 100    # view recent logs for the specific failed service
```

---

### Radxa-X4: qBittorrent can't reach the internet / DHT not working

The WireGuard handshake may have failed at startup. The `ExecStartPre` in `vpn-qbittorrent.nix` triggers a handshake before qBittorrent starts, but it can fail if the network isn't ready. Restart the service chain:

```bash
sudo systemctl restart vpn-qbt-netns                                  # restart VPN network namespace
sudo systemctl restart qbittorrent-vpn                                # restart qBittorrent (VPN handshake runs first)
sudo wg show                                                           # verify WireGuard is connected
sudo ip netns exec qbt-vpn curl https://am.i.mullvad.net/ip           # verify traffic exits through Mullvad
```

---

### nixos-config cloned as root on server — permission errors

```bash
sudo chown -R linuxury:users ~/nixos-config
```

---

### MinisForum: files owned by wrong user after rebuild

If UIDs shift between rebuilds (e.g. after adding or removing a user), files that were written under the old UID are no longer owned by the expected user. UIDs are now pinned in `hosts/MinisForum/default.nix` (linuxury=1000, babylinux=1001, alex=1002) to prevent this. If it happens again:

```bash
id linuxury          # check current UID
ls -ln /data         # check numeric ownership of files
sudo chown -R 1000:users /data/relevant-dir   # fix ownership using pinned UID
```

---

### Radxa-X4: qBittorrent downloads stop / connection drops when a SOCKS5 proxy is configured

qBittorrent crashes when a proxy is enabled in its settings. The VPN killswitch already routes all traffic through Mullvad — an additional SOCKS5 proxy is redundant and causes the crash. Leave the proxy settings blank in qBittorrent's preferences.

---

### Radxa-X4: Tailscale goes offline silently after a network blip

Tailscale can lose its tunnel after a brief network interruption and not recover on its own. The config includes a watchdog timer that runs `tailscale ping` every 5 minutes and restarts `tailscaled` if it fails. If the node appears offline in `tailscale status` from another machine:

```bash
ssh linuxury@<ip>
sudo systemctl restart tailscaled
sudo tailscale status   # verify re-connection
```

---

## SSH

### SSH key not accepted by GitHub

Add the key to GitHub if it's not there yet, or verify the agent has it loaded:

```bash
ssh -T git@github.com              # test GitHub authentication
ssh-add -l                         # list keys currently in the agent
ssh-add ~/.ssh/id_ed25519          # load the key into the agent if not listed
cat ~/.ssh/id_ed25519.pub          # copy this and add to GitHub → Settings → SSH keys
```

---

### Can't SSH to a machine that was just installed

1. Verify Tailscale is running on the target: `sudo tailscale status`
2. Confirm SSH is enabled in the host config: `services.openssh.enable = true`
3. Check the firewall allows port 22: `sudo iptables -L INPUT | grep ssh`
4. Check `authorized_keys` — linuxury's SSH key is deployed via agenix; confirm the secret was decrypted successfully on the target

---

## Disk / Storage

### Nix store is full

```bash
df -h /nix/store               # check current store usage
ngc                            # delete all old generations, then collect garbage
sudo nix-store --optimise      # hard-link identical files to reclaim space (takes a few minutes)
```

---

### NTFS drive won't mount / "can't find FUSE helper" error

NTFS mounts must use `fsType = "ntfs3"` (the kernel driver) and `boot.supportedFilesystems.ntfs = true`. The `ntfs-3g` FUSE helper is not available to systemd's mount units — using it causes a "can't find FUSE helper" error at mount time.

If a mount fails with that error, check the host config for the affected drive and ensure:

```nix
fileSystems."/mnt/DriveName" = {
  fsType = "ntfs3";   # ← not "ntfs-3g"
  ...
};
boot.supportedFilesystems.ntfs = true;
```

---

### mergerfs pool missing a drive (Media-Server)

If a drive failed, mergerfs continues with the remaining drives. Replace the drive, format it, label it, and restart the mergerfs mount:

```bash
lsblk                            # check which drives are detected
dmesg | grep sd                  # look for disk errors in the kernel log
sudo smartctl -a /dev/sdX        # check SMART health for the suspect drive
sudo e2label /dev/sdX disk1      # re-label the replacement drive so mergerfs finds it
```

---

## General Debugging

### Check what changed between two generations

```bash
nix-diff /nix/var/nix/profiles/system-<old>-link /nix/var/nix/profiles/system-<new>-link
```

### Find which package provides a binary

```bash
nix-locate --whole-name bin/some-binary
```

### Check system journal for boot errors

```bash
journalctl -b -p err      # errors from this boot
journalctl -b -1 -p err   # errors from the previous boot (useful after a crash)
```

### Show all currently failed units

```bash
systemctl --failed          # failed system units
systemctl --user --failed   # failed user units (runs as the current user)
```
