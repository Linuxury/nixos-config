# Server Management

Reference guide for the three headless servers: Media-Server, Radxa-X4, and MinisForum. All are managed over SSH from the ThinkPad or Ryzen5900x. None of them run a desktop environment — everything is configured via NixOS modules and managed via systemd.

---

## Contents

- [Connecting](#connecting)
- [Media-Server](#media-server)
  - [Services](#services)
  - [Managing Services](#managing-services)
  - [Immich](#immich)
  - [FreshRSS](#freshrss)
  - [Samba](#samba)
  - [Hard Drives (mergerfs)](#hard-drives-mergerfs)
- [Radxa-X4](#radxa-x4)
  - [VPN Status](#vpn-status)
  - [qBittorrent](#qbittorrent)
  - [Samba Share](#samba-share)
  - [Updating the VPN Config](#updating-the-vpn-config)
- [MinisForum](#minisforum)
  - [Minecraft Java](#minecraft-java)
  - [Hytale Server](#hytale-server)
  - [Samba](#samba-1)
- [General Server Tasks](#general-server-tasks)

---

## Connecting

All servers are on Tailscale — connect by hostname from any machine on the tailnet:

```bash
ssh linuxury@Media-Server
ssh linuxury@Radxa-X4
ssh linuxury@MinisForum
```

If a server isn't reachable by hostname, check its Tailscale status or use its IP directly:

```bash
sudo tailscale status   # from any machine on the tailnet — lists all connected nodes and IPs
```

---

## Media-Server

**Role:** Media streaming, Arr stack, Immich photo library, FreshRSS, Samba share.

**Hardware:** AMD RX 480 GPU — used for VAAPI hardware transcoding in Plex and Immich.

**Storage layout:**
```
/data/
├── media/          ← Plex library (movies, TV, music)
├── downloads/      ← Arr stack download staging area
├── photos/         ← Immich library
└── shared/         ← General network share files
```

Samba share: `\\Media-Server\Media-Server` → `/data`

### Services

| Service | Port | URL |
|---------|------|-----|
| Plex | 32400 | `http://Media-Server:32400/web` |
| Immich | 2283 | `http://Media-Server:2283` |
| FreshRSS | 8080 | `http://Media-Server:8080` |
| Sonarr | 8989 | `http://Media-Server:8989` |
| Radarr | 7878 | `http://Media-Server:7878` |
| Prowlarr | 9696 | `http://Media-Server:9696` |

### Managing Services

Standard systemd commands work for all services:

```bash
sudo systemctl status plex immich-server sonarr radarr   # check status of multiple services at once
sudo systemctl restart immich-server                      # restart a specific service
journalctl -u plex -f                                     # follow live logs for plex
journalctl -u immich-server -n 100                        # view last 100 log lines for immich
```

### Immich

Immich is the self-hosted photo library. Photos are stored under `/data/photos/` (or wherever the library path is configured in Immich settings).

**Permissions:** linuxury and babylinux are in the `immich` group so they can write to the library. The service runs with `UMask = "0022"` so new files are group-readable.

After adding users to the `immich` group in the NixOS config, rebuild and log out/in for the group membership to take effect:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#Media-Server
```

### FreshRSS

FreshRSS is a self-hosted RSS aggregator. Admin credentials:

- Admin user: `linuxury`
- Password: managed by agenix (`secrets/freshrss-admin-password.age`) — set via `age-edit` on your admin machine

**Mobile RSS app setup** (Fluent Reader, FeedMe, etc.):

1. Enable the API: **FreshRSS → Settings → Authentication → Allow API access**
2. API endpoint: `http://Media-Server:8080/api/greader.php`

### Samba

Desktop machines auto-mount `\\Media-Server\Media-Server` at `/mnt/Media-Server` via CIFS. Mount options:

| Option | Effect |
|--------|--------|
| Credentials from `smb-credentials.age` | Decrypted by agenix at boot |
| `x-systemd.automount` | Mounts on first access, not at boot |
| `idle-timeout=60` | Unmounts after 60 seconds idle |
| `nofail _netdev noauto` | Does not block boot if the server is off |

After first install or after adding a new user, set Samba passwords on the server (Samba passwords are separate from Linux login passwords):

```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
sudo smbpasswd -a alex
```

### Hard Drives (mergerfs)

The data drives are labeled `disk1` and `disk2`. **mergerfs** pools them into a single `/data` mount point — files written to `/data` are spread across both drives transparently. If one drive disappears, mergerfs continues with the remaining drive at reduced capacity.

Check drive health and pool status:

```bash
lsblk                          # list all block devices and their mount points
df -h                          # check filesystem usage per mount point
sudo smartctl -a /dev/sda      # check SMART health for a specific drive (replace /dev/sda)
```

---

## Radxa-X4

**Role:** Dedicated torrent host with Mullvad WireGuard VPN killswitch. All qBittorrent traffic is routed through the VPN, inside a network namespace (`vpn-qbt`). If the VPN drops, qBittorrent's network access is cut by the killswitch — your home IP is never exposed.

**Key services** (`systemctl list-units "*qbt*" "*qbittorrent*"`):

- `vpn-qbt-netns.service` — creates the network namespace + WireGuard interface (`wg-qbt`) + veth pair to the host
- `qbittorrent-vpn.service` — the qBittorrent daemon, running *inside* the namespace
- `qbittorrent-vpn-proxy.service` — proxies the web UI from the namespace out to the host's normal network, so it's reachable at a normal LAN address instead of requiring `ip netns exec` or an SSH tunnel
- `vpn-qbt-failover.timer` — checks VPN connectivity every 5 minutes, triggers `vpn-qbt-failover.service` to rotate to the next server in `failoverServers` (see `hosts/Radxa-X4/default.nix`) if the active one is down

### VPN Status & Killswitch Verification

```bash
sudo ip netns exec vpn-qbt ip addr    # confirm wg-qbt interface has an IP
sudo ip netns exec vpn-qbt ip route   # default route MUST be `dev wg-qbt` — a route to the WG endpoint itself via veth is normal, not a leak

# The real test — external IP MUST differ between these two:
sudo ip netns exec vpn-qbt curl -s --max-time 8 ifconfig.me   # should show a Mullvad exit IP
curl -s --max-time 8 ifconfig.me                                # should show your real home IP
```

If both commands return the same IP, or the namespace command times out entirely, the killswitch is not isolating traffic correctly — stop and fix this before letting any torrents run.

### qBittorrent

The web UI is proxied to the host's normal network — reachable directly, no tunnel needed:

- Web UI: `http://Radxa-X4:8080` (or `http://10.0.0.5:8080` on LAN, or via Tailscale hostname)
- **Login is not `admin`/`adminadmin`.** Modern qBittorrent (4.6+) generates a random temporary password on every service (re)start instead, logged only to journalctl:
  ```bash
  journalctl -u qbittorrent-vpn.service --no-pager | grep -i "temporary password" | tail -1
  ```
  Log in immediately and set a permanent password (Options → WebUI → Change password) — until you do, it re-randomizes on every restart/reboot, locking you out again each time.
- If login fails even with a freshly-grabbed temp password, check for an IP ban first before assuming the password is stale — qBittorrent's brute-force protection locks out an IP after repeated failed attempts (common after a couple of expired-password attempts in a row):
  ```bash
  curl -s -i -X POST http://Radxa-X4:8080/api/v2/auth/login -d "username=admin&password=<pw>"
  # "Your IP address has been banned..." means restart the service to clear the ban
  # (this also generates a fresh temp password — grab the new one after restarting)
  sudo systemctl restart qbittorrent-vpn.service
  ```

Manage the service:

```bash
sudo systemctl status qbittorrent-vpn.service    # check status
sudo systemctl restart qbittorrent-vpn.service   # restart — also clears any WebUI IP ban and issues a new temp password
journalctl -u qbittorrent-vpn.service -f          # follow live logs
```

Download paths (created via `systemd.tmpfiles.rules`, owned by `linuxury:users`):

- Complete: `/data/torrents/complete`
- Incomplete: `/data/torrents/incomplete`

### Post-Reinstall Checklist

Beyond the generic reinstall steps in [02-install-uefi.md](02-install-uefi.md), Radxa-X4 specifically needs these checked after any wipe/reformat:

1. **CIFS mount UIDs** — `/mnt/Media-Server`'s mount options hardcode a numeric `uid=`. NixOS assigns UIDs by declaration order at install time, and it is **not guaranteed to match previous installs or other hosts** — a reinstall can silently reassign `linuxury` to a different UID than before. Verify with `id linuxury` and compare against the hardcoded `uid=` in `hosts/Radxa-X4/default.nix`'s `fileSystems."/mnt/Media-Server"` block; fix if they don't match. (The same class of bug is separately tracked for MinisForum — this isn't a one-off, check it on every host with a hardcoded CIFS uid after a reinstall.)
2. **qBittorrent WebUI password** — see above; grab the fresh temp password and set a permanent one before doing anything else with it.
3. **Killswitch verification** — run the external-IP comparison above *before* trusting the VPN with real traffic, every time, not just after a fresh install.
4. **Directory ownership** — `ls -la /data /data/torrents/{complete,incomplete}` should all show `linuxury:users`; these are declarative (`systemd.tmpfiles.rules`) so they should self-correct on rebuild, but worth a glance.

### Samba Share

Share: `\\Radxa-X4\Torrents` → `/data/torrents`

This share is mounted on **Media-Server** at `/mnt/Torrents` (server-to-server), so the Arr apps can import completed downloads automatically. Desktop hosts do not mount Radxa-X4 directly.

Set Samba passwords after first boot:

```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
```

### Updating the VPN Config

To switch Mullvad servers or rotate credentials, download the new WireGuard config from the Mullvad dashboard, update the secret, commit, and rebuild:

```bash
# Place the new config at /tmp/new-config.conf, then:
cd ~/nixos-config/secrets
EDITOR="cp /tmp/new-config.conf" nix run nixpkgs#ragenix -- -e wireguard-vpnunlimited.age
git add wireguard-vpnunlimited.age
git commit -m "update VPN config to <server-name>"
git push
nru Radxa-X4   # rebuild Radxa-X4 to apply the new config
```

> The secret is named `wireguard-vpnunlimited.age` for historical reasons — it was originally VPN Unlimited before the provider was changed to Mullvad. The filename was not changed to avoid unnecessary churn.

---

## MinisForum

**Role:** Game server host — Minecraft Java and Hytale.

**Storage:** `/data/gameservers/` — shared via Samba at `\\MinisForum\GameServers`.

### Minecraft Java

Servers run under **Crafty Controller** (`https://MinisForum:8443`) — not systemd.

| Server | Port | Pack |
| --- | --- | --- |
| Dark Fortress [26.2] | 25565 | Fabric 26.2 |
| Homestead [1.3.7] | 25566 | Fabric 1.20.1 (voice chat on 24454/udp) |

Players connect to `MinisForum:<port>` (or the Tailscale IP if hostname resolution fails).

```bash
sudo systemctl status docker-crafty   # the Crafty container itself
docker port crafty                    # ports actually published to the host
```

Start/stop/console/backups all live in the web UI. Per-server logs: `servers/<uuid>/logs/latest.log`.

A new server needs its port in **both** `virtualisation.oci-containers.containers.crafty.ports`
and `networking.firewall` — Crafty alone won't make it reachable.
MC 1.20.1 packs need **Java 17** (Config tab → "Override current Java Version"); the
container's default JDK 25 crashes spark's async-profiler.

### Hytale Server

Runs in Crafty as **Hytale - Dark Fortress** (server type `hytale`). Start/stop/console/logs/backups live in the web UI.

- Port: **5520** (UDP/QUIC) — mapped by hand in `oci-containers` + `networking.firewall`, since Crafty doesn't publish UDP for Hytale
- Data: `/data/gameservers/crafty/servers/<uuid>/` (jar in `Server/`, config/mods/worlds in the root)
- Players connect to `MinisForum`

**Updates:** use Crafty's **Update Center** tab. Keep `"AutoApplyMode": "Disabled"` under `Update` in the server's
`config.json` — Hytale's built-in updater relies on `start.sh` to install staged files (exit code 8), which
Crafty doesn't run, so `WhenEmpty`/`Scheduled` just shut the server down without updating.

**Broken mods after an update:** move the jar/zip out of `mods/` (Crafty → Files), restart, re-add once the mod is updated.

### Samba

Share: `\\MinisForum\GameServers` → `/data/gameservers`

Set Samba passwords after first boot:

```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
sudo smbpasswd -a alex
```

---

## General Server Tasks

### Rebuild a server

Use `nru` from your admin machine — it SSHes in, pulls the latest config, and runs `nixos-rebuild` automatically:

```bash
nru <ServerName>   # e.g.: nru Media-Server
```

Or manually if you need to debug:

```bash
ssh linuxury@<ServerName>
cd ~/nixos-config && git pull
sudo nixos-rebuild switch --flake .#<ServerName>
```

### Fix ownership if config was cloned as root

If the nixos-config repo was cloned as root (common during server setup), fix ownership before working with it:

```bash
sudo chown -R linuxury:users ~/nixos-config
```

### Check all services quickly

List every service currently in a failed state. Any entry here needs investigation:

```bash
systemctl --failed
```

Investigate a specific failed service:

```bash
journalctl -u <service-name> -n 100   # view the last 100 log lines
journalctl -u <service-name> -f       # follow live logs
```
