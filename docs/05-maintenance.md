# 🔧 Daily Maintenance

How to keep your NixOS systems updated, healthy, and recoverable. Covers the shell abbreviations used throughout this config, the update workflow, rollback options, Btrfs snapshots, garbage collection, and updating remote servers.

---

## 📋 Contents

- [Shell Abbreviations Reference](#shell-abbreviations-reference)
- [Update Workflow](#update-workflow)
- [Using topgrade](#using-topgrade)
- [Rollback](#rollback)
- [Snapshots (Btrfs / Snapper)](#snapshots-btrfs--snapper)
- [Garbage Collection](#garbage-collection)
- [Updating Remote Servers](#updating-remote-servers)
- [Maintenance Schedule](#maintenance-schedule)

---

## ⌨️ Shell Abbreviations Reference

[↑ Back to Contents](#-contents)

These abbreviations are defined in each user's `home.nix` via `programs.zsh.zsh-abbr.abbreviations`. Type the abbreviation and press **Space** to expand it before running — the full command appears in your terminal so you always see what will run.

| Abbreviation | Expands to | What it does |
|-------------|-----------|--------------|
| `nr` | `sudo nixos-rebuild switch --flake ~/nixos-config#$(hostname)` | Rebuild and switch to the new config immediately |
| `nrb` | `sudo nixos-rebuild boot --flake ~/nixos-config#$(hostname)` | Build and queue for next boot — don't switch yet |
| `nrt` | `sudo nixos-rebuild test --flake ~/nixos-config#$(hostname)` | Apply temporarily — reverts on reboot |
| `nrr` | `sudo nixos-rebuild switch --rollback` | Roll back to the previous generation |
| `ngc` | `sudo nix-collect-garbage -d` | Delete all old generations and free disk space |
| `ngens` | `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system` | List all system generations with timestamps |
| `snaps` | `sudo snapper list` | List all Btrfs snapshots (linuxury only) |
| `snapsh` | `sudo snapper create --description "..."` | Create a manual snapshot with a description |
| `snapc` | `sudo snapper cleanup all` | Clean up snapshots outside the retention policy |
| `age-edit` | `cd ~/nixos-config/secrets && nix run nixpkgs#ragenix -- -e` | Open a secret for editing |
| `age-rekey` | `cd ~/nixos-config/secrets && nix run nixpkgs#ragenix -- -r` | Re-key all secrets with the current recipient list |

The `nru` function (defined in `dotfiles/zsh/zshrc`) rebuilds a **remote** host over SSH:

```bash
nru Media-Server    # SSHes to Media-Server, pulls the latest config, and runs nixos-rebuild there
nru Radxa-X4
nru MinisForum
```

---

## 🔄 Update Workflow

[↑ Back to Contents](#-contents)

A standard update pulls the latest config from git, updates all flake inputs (nixpkgs, home-manager, etc.) to their latest commits, rebuilds, then commits the updated lock file so other machines get the same versions:

```bash
cd ~/nixos-config
git pull                          # pull any config changes first
nix flake update                  # update all inputs to their latest commits — updates flake.lock
nr                                # rebuild and switch to the updated system
git add flake.lock
git commit -m "update flake inputs $(date +%Y-%m-%d)"
git push
```

You don't need to run `nix flake update` every time you rebuild. Run it when you want to pull in upstream package updates — weekly or before you know you need a specific package version.

> 💡 Use `nrb` if you want to stage the new config for the next boot without switching immediately — useful if you're mid-session and don't want services to restart right now.

---

## 🔁 Using topgrade

[↑ Back to Contents](#-contents)

**topgrade** is an all-in-one updater that runs multiple update steps in sequence: NixOS, Flatpaks, Cargo crates, language toolchains, and more. It's installed in linuxury's packages.

```bash
topgrade   # runs all configured updaters in sequence
```

Configure which updaters to skip in `~/.config/topgrade.toml`. The NixOS step runs `nix flake update` and `nr` automatically.

---

## ⏪ Rollback

[↑ Back to Contents](#-contents)

NixOS keeps every previous build as a "generation" — a snapshot of the entire system at the time of that rebuild. You can switch to any previous generation without rebuilding.

### Quick rollback (previous generation)

```bash
nrr   # expands to: sudo nixos-rebuild switch --rollback
```

This immediately switches to the generation before the current one. Use this when a rebuild breaks something and you want to revert fast.

### Roll back to a specific generation

List all generations first, then switch to the one you want:

```bash
ngens   # list all generations with timestamps and numbers

sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation <number>
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### Boot menu rollback (if the system won't boot)

At the systemd-boot menu (appears briefly at startup — press any key to pause it), older generations appear as separate entries. Select one to boot into a known-good state without touching the running system at all.

---

## 📸 Snapshots (Btrfs / Snapper)

[↑ Back to Contents](#-contents)

Btrfs snapshots complement NixOS generations — generations cover the system config and packages, but snapshots cover the actual filesystem state including files in `/home` that aren't managed by Nix.

> 💡 Snapshots only apply to machines with Btrfs root filesystems. All desktop and laptop hosts in this config use Btrfs. Servers may differ.

### Take a manual snapshot before risky changes

```bash
snapsh   # expands to: sudo snapper create --description "before update"
         # the description shows in the snapshot list — make it meaningful
```

### List snapshots

```bash
snaps   # expands to: sudo snapper list
        # shows snapshot number, date, type, and description
```

### Restore from a snapshot

View what changed between now and a specific snapshot, then roll back and reboot:

```bash
sudo snapper diff 5..0     # compare snapshot #5 to current state — shows changed files
sudo snapper rollback 5    # roll back the root Btrfs subvolume to snapshot #5
sudo reboot                # required — the rollback takes effect on next boot
```

### Clean up old snapshots

```bash
snapc   # expands to: sudo snapper cleanup all
```

Snapper is configured with automatic retention policies (keep N hourly/daily/weekly snapshots). This command deletes everything outside those policies. Run it after doing a rollback to clean up intermediate snapshots.

---

## 🗑️ Garbage Collection

[↑ Back to Contents](#-contents)

The Nix store (`/nix/store`) grows over time as each rebuild adds new packages. Old generations and their packages accumulate until you explicitly clean them up.

```bash
ngc   # expands to: sudo nix-collect-garbage -d
      # deletes ALL old generations, then removes unreferenced store paths
```

The `-d` flag deletes all old generations before collecting — this is aggressive. Only run it when you're confident the current system is working well and you won't need to roll back.

For a softer cleanup (keep the last 30 days of generations):

```bash
sudo nix-collect-garbage --delete-older-than 30d
```

Check current store size and deduplicate files (hard-links identical files to save space):

```bash
du -sh /nix/store          # check current store size before cleanup
sudo nix-store --optimise  # deduplicate identical files in the store — takes a few minutes
```

---

## 🖧 Updating Remote Servers

[↑ Back to Contents](#-contents)

The `nru` function SSHes into a server, pulls the latest config, and runs `nixos-rebuild` there. Push your config changes first so the server pulls the latest version:

```bash
git push           # push config changes before triggering the remote rebuild
nru Media-Server   # SSH in and rebuild
nru Radxa-X4
nru MinisForum
```

What `nru` actually runs on the server:

```bash
cd ~/nixos-config && git pull && sudo nixos-rebuild switch --flake .#<ServerName>
```

To do it manually (useful if `nru` fails or you need to debug):

```bash
ssh linuxury@Media-Server
cd ~/nixos-config
git pull
sudo nixos-rebuild switch --flake .#Media-Server
```

---

## 📋 Maintenance Schedule

[↑ Back to Contents](#-contents)

| Frequency | Task |
|-----------|------|
| After any config change | `nr` to apply the change |
| Weekly | `nix flake update` + `nr` on each machine + `nru` for each server |
| Monthly | `ngc` on all machines to recover disk space |
| Before major changes | `snapsh` to take a manual Btrfs snapshot first |
| When adding a new machine | Add host key to `secrets.nix`, re-key, commit, rebuild |
| When rotating VPN or credentials | Update the secret via `age-edit`, commit, `nru Radxa-X4` |
