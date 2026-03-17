# 🆘 Troubleshooting

Common failures, their causes, and how to fix them. Organized by area. For deeper context on any topic, the relevant doc is linked in the section header.

---

## 📋 Contents

- [Rebuild / nixos-rebuild](#rebuild--nixos-rebuild)
- [Secrets / ragenix](#secrets--ragenix)
- [Network / Tailscale / Samba](#network--tailscale--samba)
- [Theming / matugen](#theming--matugen)
- [COSMIC / Desktop](#cosmic--desktop)
- [Gaming](#gaming)
- [Servers](#servers)
- [SSH](#ssh)
- [Disk / Storage](#disk--storage)
- [General Debugging](#general-debugging)

---

## 🔄 Rebuild / nixos-rebuild

[↑ Back to Contents](#-contents)

### `error: flake 'git+file:///...' does not provide attribute`

The hostname passed to `--flake .#<HostName>` doesn't match any entry in `flake.nix`. Host names are case-sensitive — `ThinkPad` works, `thinkpad` does not. Check the exact names:

```bash
grep -A1 "mkHost" ~/nixos-config/flake.nix | grep hostname   # prints all valid host names
```

---

### Rebuild fails with hash mismatch or `fixed-output derivation` error

A Nix fetch got a different file than expected — remote content changed or a network error returned partial data. Refresh the lock file and rebuild:

```bash
nix flake update   # refresh lock file with current upstream commits
nr                 # rebuild with updated inputs
```

---

### `warning: Git tree ... is dirty` — build ignores my changes

Nix flakes only see **committed** files. Untracked or uncommitted changes are invisible to the build system. Stage and commit first, then rebuild:

```bash
git add -A && git commit -m "wip"
nr
```

---

### Home Manager activation fails with `checkLinkTargets`

A file that Home Manager wants to manage already exists on disk and isn't a symlink from HM. Find the conflicting file named in the error, back it up, then rebuild:

```bash
mv ~/.config/conflicting-file ~/.config/conflicting-file.bak
nr
```

---

## 🔐 Secrets / ragenix

[↑ Back to Contents](#-contents)

See [04-secrets.md](04-secrets.md) for the full secrets workflow.

### `agenix: secret cannot be decrypted with any of the given keys`

The machine's host key isn't listed as a recipient for this secret in `secrets/secrets.nix`. Add it and re-key:

1. Get the host key: `cat /etc/ssh/ssh_host_ed25519_key.pub`
2. Add it to `secrets.nix` under the appropriate secret's `publicKeys` list
3. Re-key from your admin machine: `age-rekey`
4. Commit, push, and rebuild the target machine

---

### `ragenix: identity not found`

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

## 🌐 Network / Tailscale / Samba

[↑ Back to Contents](#-contents)

### Tailscale is connected but hostname doesn't resolve

DNS propagation may be lagging. Use the IP directly while waiting, or check the current IP:

```bash
sudo tailscale status    # shows all nodes and their Tailscale IPs
ping 100.x.x.x           # use IP directly to test connectivity
```

---

### CIFS mount fails: `mount error(13): Permission denied`

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

## 🎨 Theming / matugen

[↑ Back to Contents](#-contents)

See [09-theming.md](09-theming.md) for the full theming pipeline.

### Terminal colors stopped updating when wallpaper changes

Check the color-sync service status, then force a refresh:

```bash
systemctl --user status wallpaper-color-sync              # check service status
journalctl --user -u wallpaper-color-sync -n 50           # view recent logs
rm ~/.local/share/last-matugen-wallpaper                  # clear the feedback-loop prevention cache
systemctl --user restart wallpaper-color-sync             # force a run now
```

---

### COSMIC desktop flashing / `cosmic-session` restarting in a loop

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

The matugen seed files (`~/.config/kitty/colors.conf`, `~/.config/ghostty/colors`) are missing or empty, and matugen hasn't run yet. Re-run Home Manager activation to recreate them, then force matugen:

```bash
home-manager switch --flake ~/nixos-config#linuxury   # recreate seed files
rm ~/.local/share/last-matugen-wallpaper              # clear cache
systemctl --user restart wallpaper-color-sync         # force matugen to run
```

---

## 🖥️ COSMIC / Desktop

[↑ Back to Contents](#-contents)

See [10-de-wm.md](10-de-wm.md) for full COSMIC DE documentation.

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

## 🎮 Gaming

[↑ Back to Contents](#-contents)

See [08-gaming.md](08-gaming.md) for full gaming setup documentation.

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

## 🖧 Servers

[↑ Back to Contents](#-contents)

See [06-servers.md](06-servers.md) for full server management documentation.

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

## 🔑 SSH

[↑ Back to Contents](#-contents)

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

## 💾 Disk / Storage

[↑ Back to Contents](#-contents)

### Nix store is full

```bash
df -h /nix/store               # check current store usage
ngc                            # delete all old generations, then collect garbage
sudo nix-store --optimise      # hard-link identical files to reclaim space (takes a few minutes)
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

## 🧰 General Debugging

[↑ Back to Contents](#-contents)

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
