# Nix Updates

Shows which packages would change on your next NixOS update, before you build
anything, and runs the update on demand. It compares the package versions in
your flake's current `flake.lock` against newer inputs, and can also list
pending Flatpak updates.

## Plugin

| Field | Value |
| --- | --- |
| ID | `linuxury/nix-updates` |
| Entries | Bar widget: `widget`; panel: `panel`; service: `service` |

## Requirements

- A NixOS system configured from a flake, with `nix` (flakes enabled) and
  `nixos-rebuild`.
- `git`, but only for **Compare against → flake.lock on the git remote**.
- `flatpak`, but only when **Include Flatpak updates** is on. Without it the
  Flatpak section stays empty.
- `sudo` for the default **Update now** command. The `nixos-rebuild switch`
  step needs root.
- `systemd-run`, but only when **Terminal command** is set (see Notes).
- Standard tools used by the check script: `flock`, `join`, `awk`, `sort`,
  `mktemp`, `realpath`, `hostname`, `cmp`.

## Usage

1. Enable the plugin and set **Flake directory** to the folder that holds your
   `flake.nix` (default `/etc/nixos`, symlinks are fine).
2. Add the `widget` bar widget. It only shows up when updates are pending, as
   `❄ <nix count>  󰏖 <flatpak count>`. A count of zero is left out. Turn on
   **Always show bar icon** to keep the icon in the bar when everything is up
   to date.
3. Click the widget, or run the command below, to open the panel:

```sh
noctalia msg panel-toggle linuxury/nix-updates:panel
```

The panel lists every pending change as `name  old → new`, grouped into
**NixOS** and **Flatpak**, and shows when the last check ran. A Flatpak that
Flathub rebuilt without changing its version shows as `old → rebuild <commit>`
(the first 7 characters of the new commit), so you can tell it's a real update.

- **Check now** runs a check right away.
- **Update now** opens a terminal that runs the update method (see Settings),
  then re-checks, so the count resets once the update succeeds.
- The gear button opens the plugin settings.

When a background check finds more updates than before, a notification lists
the first eight.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `flake_dir` | `folder` | `/etc/nixos` | Directory containing your system `flake.nix`. Its `flake.lock` is only read, never modified by a check. |
| `host` | `string` | `""` | `nixosConfigurations` attribute to check. Empty means this machine's hostname. |
| `compare` | `select` | `upstream` | `upstream`: the newest version of every flake input (`nix flake update` into a temporary lock file). `remote`: the `flake.lock` on the git upstream branch (`@{u}`), for machines that only pull a lock another machine updates. This mode makes no GitHub API calls. |
| `include_flatpak` | `bool` | `true` | Also list pending Flatpak updates, user and system installations. |
| `always_show` | `bool` | `false` | Keep the bar widget visible when there is nothing to update. |
| `update_method` | `select` | `nixos-rebuild` | `nixos-rebuild`: `nix flake update` (with `sudo` if `flake.lock` isn't writable), then `sudo nixos-rebuild switch --flake .#<host>`. `custom`: run **Custom command** instead. |
| `custom_command` | `string` | `""` | Shell command for the `custom` method, e.g. `topgrade`, or `zsh -ic nru` to call a shell function. |
| `terminal` | `string` | `""` | Prefix that runs a command in a terminal, e.g. `kitty --class nix-updates -e`. Empty uses `$TERMINAL`. |
| `check_interval` | `select` | `6` (hours) | How often to check in the background: 15 or 30 minutes, 1, 3, 6, 12 or 24 hours, or manually only. The first check runs 15 seconds after the shell starts, unless one ran in the last 30 minutes. A failed check is retried after 1, 5, then 15 minutes. |

## Notes

- **What it compares.** A check evaluates `environment.systemPackages` and every
  Home Manager user's `home.packages` with the current lock and with the newer
  one, then lists the name/version pairs that differ. Nothing is built.
  Patch-only rebuilds and packages pulled in by modules (kernel, libraries)
  aren't listed, because catching those needs a full closure diff, i.e. a build.
- **Network.** In `upstream` mode every check resolves each flake input, which
  for GitHub inputs means unauthenticated GitHub API calls (60 per hour per IP,
  shared by every machine behind it). Prefer intervals of 1 hour or more, or use
  `remote` mode on machines that don't update the lock themselves. `remote` mode
  only runs `git fetch`. Flatpak mode runs `flatpak remote-ls --updates`.
- **Files written.** The result is written to the plugin's data directory
  (`result`, plus a `result.lock` used so that only one check runs at a time).
  Temporary files go under `mktemp -d` and are removed afterwards. Your
  flake's `flake.lock` is never touched by a check. Only **Update now** with
  the default method updates it.
- **Processes.** Checks run `check.sh` in the background (`nix eval`,
  `nix flake update --output-lock-file`, `git fetch`, `flatpak`). **Update now**
  runs the update in a terminal you can see. When **Terminal command** is set,
  the terminal is started with `systemd-run --user --scope`, so a rebuild that
  restarts the shell doesn't kill the update in progress.
- **Debugging.** If a check fails, the panel shows the last lines of nix's
  error output. Run the same check by hand with
  `sh check.sh <flake_dir> [host] /tmp/out [upstream|remote] [0|1]`.
