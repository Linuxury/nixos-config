# 🖧 Server Management

Reference guide for the three headless servers: Media-Server, Radxa-X4, and MinisForum. All are managed over SSH from the ThinkPad or Ryzen5900x. None of them run a desktop environment — everything is configured via NixOS modules and managed via systemd.

---

## 📋 Contents

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

## 🌐 Connecting

[↑ Back to Contents](#-contents)

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

## 📺 Media-Server

[↑ Back to Contents](#-contents)

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

[↑ Media-Server](#media-server)

Standard systemd commands work for all services:

```bash
sudo systemctl status plex immich-server sonarr radarr   # check status of multiple services at once
sudo systemctl restart immich-server                      # restart a specific service
journalctl -u plex -f                                     # follow live logs for plex
journalctl -u immich-server -n 100                        # view last 100 log lines for immich
```

### Immich

[↑ Media-Server](#media-server)

Immich is the self-hosted photo library. Photos are stored under `/data/photos/` (or wherever the library path is configured in Immich settings).

**Permissions:** linuxury and babylinux are in the `immich` group so they can write to the library. The service runs with `UMask = "0022"` so new files are group-readable.

After adding users to the `immich` group in the NixOS config, rebuild and log out/in for the group membership to take effect:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#Media-Server
```

### FreshRSS

[↑ Media-Server](#media-server)

FreshRSS is a self-hosted RSS aggregator. Admin credentials are:

- Admin user: `linuxury`
- Password: managed by agenix (`secrets/freshrss-admin-password.age`) — set via `age-edit` on your admin machine

**Mobile RSS app setup** (Fluent Reader, FeedMe, etc.):

1. Enable the API: **FreshRSS → Settings → Authentication → Allow API access**
2. API endpoint: `http://Media-Server:8080/api/greader.php`

### Samba

[↑ Media-Server](#media-server)

Desktop machines auto-mount `\\Media-Server\Media-Server` at `/mnt/Media-Server` via CIFS. Mount options:

| Option | Effect |
|--------|--------|
| Credentials from `smb-credentials.age` | Decrypted by agenix at boot |
| `x-systemd.automount` | Mounts on first access, not at boot |
| `idle-timeout=60` | Unmounts after 60 seconds idle |
| `nofail _netdev noauto` | Does not block boot if the server is off |

After first install or after adding a new user, set Samba passwords on the server (Samba passwords are separate from Linux login passwords):

```bash
sudo smbpasswd -a linuxury    # prompts for Samba password twice
sudo smbpasswd -a babylinux
sudo smbpasswd -a alex
```

### Hard Drives (mergerfs)

[↑ Media-Server](#media-server)

The data drives are labeled `disk1` and `disk2`. **mergerfs** pools them into a single `/data` mount point — files written to `/data` are spread across both drives transparently. If one drive disappears, mergerfs continues with the remaining drive at reduced capacity.

Check drive health and pool status:

```bash
lsblk                          # list all block devices and their mount points
df -h                          # check filesystem usage per mount point
sudo smartctl -a /dev/sda      # check SMART health for a specific drive (replace /dev/sda)
```

---

## 🌊 Radxa-X4

[↑ Back to Contents](#-contents)

**Role:** Dedicated torrent host with Mullvad WireGuard VPN killswitch. All qBittorrent traffic is routed through the VPN. If the VPN drops, qBittorrent's network access is cut by the killswitch — your home IP is never exposed.

**Key constraint:** The qBittorrent web UI runs inside a network namespace (`qbt-vpn`) that can only reach the internet through the VPN interface. It is not accessible from the regular network.

### VPN Status

[↑ Radxa-X4](#radxa-x4)

```bash
sudo wg show                                                  # check WireGuard interface — shows peer handshake time
sudo systemctl status vpn-qbt-netns wireguard-vpnunlimited   # check both VPN services
sudo ip netns exec qbt-vpn curl https://am.i.mullvad.net/ip  # verify traffic exits through Mullvad (shows Mullvad IP)
```

Current active server: **us-mia-wg-001** (US Miami) — confirmed working at ~18 MB/s.

### qBittorrent

[↑ Radxa-X4](#radxa-x4)

The web UI is inside the VPN network namespace — only reachable via Tailscale or an SSH tunnel:

- Web UI: `http://10.200.200.2:8080`
- Default login: `admin` / `adminadmin` — **change this on first boot**

Manage the service:

```bash
sudo systemctl status qbittorrent-vpn    # check status
sudo systemctl restart qbittorrent-vpn   # restart — VPN handshake runs automatically before qBit starts
journalctl -u qbittorrent-vpn -f         # follow live logs
```

The `ExecStartPre` hook in `vpn-qbittorrent.nix` triggers a WireGuard handshake before qBittorrent starts. This prevents the DHT bootstrap race condition where qBittorrent tries to connect before the VPN tunnel is fully established.

Download paths:

- Complete: `/data/torrents/complete`
- Incomplete: `/data/torrents/incomplete`

### Samba Share

[↑ Radxa-X4](#radxa-x4)

Share: `\\Radxa-X4\Torrents` → `/data/torrents`

This share is mounted on **Media-Server** at `/mnt/Torrents` (server-to-server), so the Arr apps can import completed downloads automatically. Desktop hosts do **not** mount Radxa-X4 directly.

Set Samba passwords after first boot:

```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
```

### Updating the VPN Config

[↑ Radxa-X4](#radxa-x4)

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

> 💡 The secret is named `wireguard-vpnunlimited.age` for historical reasons — it was originally VPN Unlimited before the provider was changed to Mullvad (VPN Unlimited was blocking BitTorrent ports). The filename was not changed to avoid unnecessary churn.

---

## 🎮 MinisForum

[↑ Back to Contents](#-contents)

**Role:** Game server host — Minecraft Java and a Hytale server placeholder.

**Storage:** `/data/gameservers/` — shared via Samba at `\\MinisForum\GameServers`.

### Minecraft Java

[↑ MinisForum](#minisforum)

- Port: **25565** (TCP)
- Data: `/data/gameservers/minecraft/`

```bash
sudo systemctl status minecraft-server    # check status
journalctl -u minecraft-server -f         # follow the live server console
sudo systemctl restart minecraft-server   # restart
```

Connect from Minecraft: `MinisForum:25565` (or the Tailscale IP if hostname resolution fails)

### Hytale Server

[↑ MinisForum](#minisforum)

- Port: **5520** (UDP)
- Data: `/data/gameservers/hytale/Server/`
- Starts automatically at boot

```bash
sudo systemctl start hytale-server    # start the server
sudo systemctl stop hytale-server     # stop the server
sudo systemctl status hytale-server   # check status
journalctl -u hytale-server -f        # view logs
```

Players connect to `MinisForum:5520`.

> 💡 If server files are missing, the service will silently wait — it won't crash or fill logs. Download the server files first (see First-Time Setup below), then start the service.

#### Hytale First-Time Setup

> Skip if the server is already running.

SSH in and download the Hytale downloader tool, then use it to download the server files:

```bash
ssh linuxury@MinisForum
cd /data/gameservers/hytale
wget https://downloader.hytale.com/hytale-downloader.zip   # download the downloader
unzip hytale-downloader.zip
chmod +x hytale-downloader-linux-amd64
./hytale-downloader-linux-amd64 -download-path server.zip  # download the actual server files
unzip server.zip -d .
mv Assets.zip Server/
```

Run the server manually once to authenticate with your Hytale account (only needed once):

```bash
cd Server
java -jar HytaleServer.jar --assets Assets.zip --bind 0.0.0.0:5520
```

At the server console prompt, run the device authentication flow:

```
/auth login device
```

Follow the URL and code shown in the terminal to authenticate with your Hytale account, then enable persistent authentication:

```
/auth persistence Encrypted
```

Press `Ctrl+C` to stop the manual run, then start it via systemd:

```bash
sudo systemctl start hytale-server
```

#### Hytale Updates

Stop the service, download the latest version using the downloader tool (it handles incremental updates), replace the files, then start again:

```bash
sudo systemctl stop hytale-server
cd /data/gameservers/hytale
./hytale-downloader-linux-amd64 -download-path server.zip   # download latest version
unzip -o server.zip -d .                                     # -o overwrites existing files
mv -f Assets.zip Server/
sudo systemctl start hytale-server
```

### Samba

[↑ MinisForum](#minisforum)

Share: `\\MinisForum\GameServers` → `/data/gameservers`

Set Samba passwords after first boot:

```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
sudo smbpasswd -a alex
```

---

## 🔁 General Server Tasks

[↑ Back to Contents](#-contents)

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
