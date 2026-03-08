# Hytale Server Guide

This is the Hytale dedicated server running on MinisForum.
All commands below are run over SSH on MinisForum.

> **SSH in from your computer:**
> ```
> ssh linuxury@MinisForum
> ```

---

## Starting and Stopping

**Start the server:**
```bash
sudo systemctl start hytale-server
```

**Stop the server:**
```bash
sudo systemctl stop hytale-server
```

**Restart the server** (useful after a config change):
```bash
sudo systemctl restart hytale-server
```

**Check if it's running:**
```bash
sudo systemctl status hytale-server
```
Look for `Active: active (running)` in green — that means it's up.
If you see `inactive` or `failed`, check the logs (see below).

> The server starts **automatically on boot** — you don't need to do anything after a reboot.

---

## Reading the Logs

Watch the live log output (press `Ctrl+C` to stop watching):
```bash
journalctl -u hytale-server -f
```

Read the last 100 lines (useful for checking what happened after a crash):
```bash
journalctl -u hytale-server -n 100
```

---

## Updating the Server

Hypixel Studios releases updates through the same downloader tool.
Run these commands one at a time:

```bash
# 1. Stop the server first
sudo systemctl stop hytale-server

# 2. Go to the Hytale folder
cd /data/gameservers/hytale

# 3. Download the latest version
./hytale-downloader-linux-amd64 -download-path server.zip

# 4. Extract it (the -o flag overwrites the old files automatically)
unzip -o server.zip -d .

# 5. Move the updated assets into the Server folder
mv -f Assets.zip Server/

# 6. Start the server again
sudo systemctl start hytale-server
```

> Your login credentials and any server settings are stored separately
> and will **not** be lost when you update.

---

## First-Time Setup

> You only need to do this once — skip this section if the server is already running.

```bash
# 1. Go to the Hytale folder
cd /data/gameservers/hytale

# 2. Download the downloader tool
wget https://downloader.hytale.com/hytale-downloader.zip
unzip hytale-downloader.zip
chmod +x hytale-downloader-linux-amd64

# 3. Download the server files
./hytale-downloader-linux-amd64 -download-path server.zip
unzip server.zip -d .
mv Assets.zip Server/

# 4. Run the server manually to log in (only needed this once)
cd Server
java -jar HytaleServer.jar --assets Assets.zip --bind 0.0.0.0:5520
```

Once the server is running you'll see a console prompt. Type these two commands:

```
/auth login device
```
It will give you a URL and a short code. Open the URL on your phone or computer,
enter the code, and log in with your Hytale account.

```
/auth persistence Encrypted
```
This saves your login so the server remembers it after every reboot.

Then press `Ctrl+C` to stop the manual run, and start it properly via systemd:
```bash
sudo systemctl start hytale-server
```

---

## Quick Reference

| What you want to do | Command |
|---|---|
| Start the server | `sudo systemctl start hytale-server` |
| Stop the server | `sudo systemctl stop hytale-server` |
| Restart the server | `sudo systemctl restart hytale-server` |
| Check if it's running | `sudo systemctl status hytale-server` |
| Watch live logs | `journalctl -u hytale-server -f` |

---

## Notes

- The server uses **port 5520** (UDP). Make sure players connect to `MinisForum:5520`.
- Server files are stored in `/data/gameservers/hytale/Server/`.
- If the server files are missing, the service will silently wait — it will not crash or spam errors.
