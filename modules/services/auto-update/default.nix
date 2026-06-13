# ===========================================================================
# modules/services/auto-update/default.nix — Automatic System Updates
#
# Two-tier update model:
#
#   ┌─────────────────────────────────────────────────────────────────────┐
#   │ PRIMARY HOST (isPrimary = true — Ryzen5900x)                        │
#   │   Session start (once per 20h):                                     │
#   │     1. git pull --autostash (sync any remote config changes)        │
#   │     2. nix flake update → advances nixpkgs pin in flake.lock        │
#   │     3. nixos-rebuild switch --flake /local/nixos-config#hostname    │
#   │     4. git commit + push flake.lock → other hosts see new packages  │
#   │     5. Vault log + desktop toast + email on failure                 │
#   └─────────────────────────────────────────────────────────────────────┘
#   ┌─────────────────────────────────────────────────────────────────────┐
#   │ NON-PRIMARY HOSTS (isPrimary = false, default)                      │
#   │   Session start:                                                    │
#   │     1. git ls-remote → compare GitHub HEAD to last-built rev        │
#   │     2. Skip if same rev AND last build < 30 days ago                │
#   │     3. nixos-rebuild switch --flake github:linuxury/nixos-config    │
#   │     4. Record new rev to /etc/nixos-last-update-rev                 │
#   │     5. Vault log + desktop toast + email on failure                 │
#   │   Weekly (system.autoUpgrade, Sat 03:00):                           │
#   │     → Rebuilds from GitHub as safety net for always-on machines     │
#   └─────────────────────────────────────────────────────────────────────┘
#
# Per-host configuration:
#   services.nixos-auto-update.primaryUser    = "babylinux"; # default: linuxury
#   services.nixos-auto-update.isPrimary      = true;         # Ryzen5900x only
#   services.nixos-auto-update.nixosConfigPath = "/home/linuxury/nixos-config";
#
# To disable on a specific host:
#   Import this module and override: services.nixos-auto-update.enable = lib.mkForce false;
#   (No-op — to truly disable, don't import the module)
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  notifyScript    = ./scripts/notify-update-result.sh;
  nixosLogRebuild = pkgs.writeShellScriptBin "nixos-log-rebuild"
    (builtins.readFile ./scripts/nixos-log-rebuild.sh);
  cfg             = config.services.nixos-auto-update;
in

{
  # =========================================================================
  # Options
  # =========================================================================
  options.services.nixos-auto-update = {

    primaryUser = lib.mkOption {
      type        = lib.types.str;
      default     = "linuxury";
      description = ''
        Primary user on this host. Vault writes, notification ownership, and
        the smtp-app-password secret are all scoped to this user.
        Set to "babylinux" on her machines, "alex" on his, etc.
      '';
    };

    isPrimary = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = ''
        When true, this host owns the nixpkgs update cycle:
          - Runs nix flake update to advance the nixpkgs pin
          - Builds from the local nixos-config directory (not GitHub)
          - Commits and pushes the updated flake.lock to GitHub
        All other hosts then rebuild from GitHub and receive the new packages.
        Set to true on exactly ONE host — the admin's primary machine.
      '';
    };

    nixosConfigPath = lib.mkOption {
      type        = lib.types.str;
      default     = "/home/linuxury/nixos-config";
      description = ''
        Absolute path to the nixos-config git repository on this host.
        Only used when isPrimary = true. The primaryUser must have write
        access and a working git push credential (SSH key to GitHub).
      '';
    };

    schedule = lib.mkOption {
      type        = lib.types.str;
      default     = "*-*-* 03:00";
      description = ''
        systemd OnCalendar expression for the system.autoUpgrade timer.
        Defaults to daily at 3am. Override per-host if needed.
        Examples: "daily", "Sat 03:00" (weekly), "*-*-* 03:00" (daily 3am).
        Desktops also run on session start via a user service, so the timer
        is mainly a catch-all for machines that haven't been logged into.
      '';
    };

  };

  # =========================================================================
  # Config
  # =========================================================================
  config = {

  # =========================================================================
  # Email — msmtp (lightweight SMTP client, no daemon)
  #
  # Used by notify-update-result.sh to send failure emails.
  # Only invoked when an update fails — zero overhead otherwise.
  #
  # Requires agenix secret: smtp-app-password
  # Generate Gmail app password at: https://myaccount.google.com/apppasswords
  # =========================================================================
  programs.msmtp = {
    enable = true;
    setSendmail = true;
    defaults = {
      aliases = "/etc/aliases";
      port = 587;
      tls = true;
      tls_starttls = true;
    };
    accounts.default = {
      host = "smtp.gmail.com";
      auth = true;
      user = "linuxurypr@gmail.com";
      passwordeval = "cat /run/agenix/smtp-app-password";
      from = "linuxurypr@gmail.com";
    };
  };

  # SMTP password via agenix — owned by the primary user so the
  # notify-vault@ service (which runs as primaryUser) can read it.
  age.secrets.smtp-app-password = {
    file  = ../../../secrets/smtp-app-password.age;
    mode  = "0400";
    owner = cfg.primaryUser;
  };

  # =========================================================================
  # Scheduled weekly update — safety net for always-on machines
  #
  # Rebuilds from GitHub every Saturday 3am. On non-primary hosts this picks
  # up whatever flake.lock the primary pushed during the week (including the
  # updated nixpkgs pin). On the primary host it also runs, but the session-
  # start service is what does the real work (flake update + push).
  #
  # Persistent = true (via systemd): if the machine was off at 3am Saturday,
  # the timer fires on next boot. This catches "missed auto-update" cases.
  # =========================================================================
  system.autoUpgrade = {
    enable             = true;
    flake              = "github:linuxury/nixos-config";
    dates              = cfg.schedule;
    allowReboot        = false;
    # Spread runs across 45min so all 9 machines don't hit GitHub at once.
    randomizedDelaySec = "45min";
    # Run on next boot if the machine was off when the timer fired.
    persistent         = true;
  };

  # =========================================================================
  # Vault notification service — writes to Obsidian vault as primaryUser
  #
  # This system service runs as the host's primary user, regardless of who
  # triggered the update (root via weekly timer, or any user via session
  # start). This ensures vault writes land in the right ~/Obsidian with
  # correct ownership for Syncthing to sync.
  #
  # Called via: systemctl start notify-vault@success.service
  #             systemctl start notify-vault@failure.service
  #
  # XDG_RUNTIME_DIR uses UID 1000 — the primary user is always the first
  # normal user created on each machine (babylinux=1000, linuxury=1000, etc).
  # =========================================================================
  systemd.services."notify-vault@" = {
    description = "Write update notification to Obsidian vault (%i)";
    # These packages are not in the minimal system service PATH — must be explicit
    path = with pkgs; [ hostname coreutils gnugrep gnused gawk nix msmtp libnotify curl nixosLogRebuild ];
    serviceConfig = {
      Type      = "oneshot";
      User      = cfg.primaryUser;
      Group     = "users";
      ExecStart = "${pkgs.bash}/bin/bash ${notifyScript} %i /var/log/nixos-auto-update.log";
      # notify-send needs XDG_RUNTIME_DIR + D-Bus session socket
      # msmtp needs HOME to find its config
      Environment = [
        "XDG_RUNTIME_DIR=/run/user/1000"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
        "HOME=/home/${cfg.primaryUser}"
      ];
    };
  };

  # =========================================================================
  # Weekly schedule notification hooks
  #
  # system.autoUpgrade has no built-in hooks. These systemd overrides
  # trigger notify-vault@.service (which runs as primaryUser) when the
  # weekly update succeeds or fails.
  # =========================================================================
  systemd.services.nixos-upgrade.onSuccess = [ "notify-vault@success.service" ];
  systemd.services.nixos-upgrade.onFailure = [ "notify-vault@failure.service" ];

  # =========================================================================
  # Update log and stamp files — pre-created with primaryUser ownership
  #
  # /var/log/ and /etc/ are root-owned; tmpfiles creates these up front so
  # the update script (running as primaryUser) can write to them directly.
  # =========================================================================
  systemd.tmpfiles.rules = [
    "f /var/log/nixos-auto-update.log  0640 ${cfg.primaryUser} users -"
    # Stamp files are world-writable so any logged-in user running the session-start
    # service can write them — the primaryUser is the typical writer, but a secondary
    # user (e.g. linuxury SSHing into babylinux's machine) must not cause a false
    # "rebuild failed" report just because they can't write to a root-owned file.
    "f /etc/nixos-last-update-time     0666 root root -"
    "f /etc/nixos-last-update-rev      0666 root root -"
  ];

  # =========================================================================
  # Update script
  #
  # Two code paths:
  #
  #   isPrimary = true  — runs nix flake update, builds from local repo,
  #                       commits + pushes flake.lock so other hosts benefit
  #
  #   isPrimary = false — checks GitHub HEAD rev against last-built rev,
  #                       skips if nothing changed (with 30-day fallback),
  #                       builds from GitHub with the primary's updated lock
  # =========================================================================
  environment.systemPackages = [
    nixosLogRebuild
  ] ++ lib.optionals cfg.isPrimary [ pkgs.git ]
    ++ [
    (pkgs.writeShellScriptBin "nixos-auto-update" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # ── Arguments ────────────────────────────────────────────────────────
      FORCE=false
      case "''${1:-}" in
        --force|-f) FORCE=true ;;
        --help|-h)
          echo "Usage: nixos-auto-update [--force]"
          echo "  --force, -f   Bypass update check, run immediately"
          exit 0
          ;;
      esac

      # ── Configuration ─────────────────────────────────────────────────────
      IS_PRIMARY="${if cfg.isPrimary then "true" else "false"}"
      NIXOS_CONFIG_PATH="${cfg.nixosConfigPath}"
      TIMESTAMP_FILE="/etc/nixos-last-update-time"
      REV_FILE="/etc/nixos-last-update-rev"
      FLAKE="github:linuxury/nixos-config"
      HOSTNAME=$(hostname)
      LOG_FILE="/var/log/nixos-auto-update.log"
      REMOTE_REV=""

      # ── Logging ──────────────────────────────────────────────────────────
      log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

      # ── Reboot check ─────────────────────────────────────────────────────
      reboot_required() {
        local current installed
        current=$(uname -r)
        installed=$(ls /run/current-system/kernel-modules/lib/modules/ 2>/dev/null | head -1)
        [[ -n "$installed" && "$current" != "$installed" ]]
      }

      # ── Transient error check ─────────────────────────────────────────────
      is_transient_error() {
        grep -qiE "timed out|timeout|connection refused|couldn't connect|network" \
          "$LOG_FILE" 2>/dev/null
      }

      # ── Update-needed decision ────────────────────────────────────────────
      if [[ "$FORCE" == "true" ]]; then
        log "Force flag — proceeding with update"

      elif [[ "$IS_PRIMARY" == "true" ]]; then
        # Primary: at most once every 20h to avoid hammering on repeated logins
        last_update=0
        [[ -f "$TIMESTAMP_FILE" ]] && last_update=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo 0)
        now=$(date +%s)
        diff_hours=$(( (now - last_update) / 3600 ))
        if [[ $diff_hours -lt 20 ]]; then
          log "Primary host: updated ''${diff_hours}h ago — next update after 20h elapsed"
          exit 2
        fi
        log "Primary host: ''${diff_hours}h since last update — running full update"

      else
        # Non-primary: rebuild only when GitHub HEAD rev changed.
        # curl is used (not git ls-remote) — git is not installed on babylinux/alex
        # machines. The vnd.github.sha media type returns the 40-char SHA as plain
        # text with no JSON parsing. Falls back to time-based check if unreachable.
        REMOTE_REV=$(curl -sf --max-time 10 \
          -H "Accept: application/vnd.github.sha" \
          "https://api.github.com/repos/linuxury/nixos-config/commits/main" \
          2>/dev/null) || true
        LAST_REV=$(cat "$REV_FILE" 2>/dev/null || echo "")

        if [[ -n "$REMOTE_REV" && "$REMOTE_REV" == "$LAST_REV" ]]; then
          # Rev is same — check 30-day safety fallback
          last_update=0
          [[ -f "$TIMESTAMP_FILE" ]] && last_update=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo 0)
          now=$(date +%s)
          diff_days=$(( (now - last_update) / 86400 ))
          if [[ $diff_days -lt 30 ]]; then
            log "Already at ''${REMOTE_REV:0:8} — no changes in ''${diff_days}d, skipping"
            exit 2
          fi
          log "Rev unchanged but 30-day fallback triggered (''${diff_days}d since last build)"
        elif [[ -n "$REMOTE_REV" ]]; then
          log "GitHub HEAD: ''${REMOTE_REV:0:8}, last built: ''${LAST_REV:0:8} — update needed"
        else
          # GitHub unreachable — fall back to 7-day time check
          log "GitHub unreachable — falling back to time-based check"
          last_update=0
          [[ -f "$TIMESTAMP_FILE" ]] && last_update=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo 0)
          now=$(date +%s)
          diff_days=$(( (now - last_update) / 86400 ))
          if [[ $diff_days -lt 7 ]]; then
            log "GitHub unreachable and last build was ''${diff_days}d ago — skipping"
            exit 2
          fi
          log "GitHub unreachable but ''${diff_days}d since last build — forcing rebuild"
        fi
      fi

      log "Starting NixOS system update..."

      # ── Start notifications ────────────────────────────────────────────
      curl -s --max-time 10 \
        -H "Title: Update Starting — $HOSTNAME" \
        -H "Priority: low" \
        -H "Tags: arrows_counterclockwise" \
        -d "Fetching latest config and rebuilding... $(date '+%H:%M')" \
        "http://media-server:2586/nixos-updates" 2>/dev/null || true

      notify-send \
        --app-name "NixOS Update" \
        --icon "system-software-update" \
        --urgency normal \
        "NixOS Update Starting" \
        "Rebuilding system in the background..." 2>/dev/null || true

      # ── Primary: git pull + nix flake update ─────────────────────────
      if [[ "$IS_PRIMARY" == "true" ]]; then
        log "Pulling latest remote changes..."
        git -C "$NIXOS_CONFIG_PATH" pull --rebase --autostash 2>&1 | tee -a "$LOG_FILE" || \
          log "WARN: git pull failed — continuing with local state"

        log "Updating nixpkgs pin (nix flake update)..."
        nix flake update "$NIXOS_CONFIG_PATH" 2>&1 | tee -a "$LOG_FILE"

        FLAKE_REF="$NIXOS_CONFIG_PATH"
      else
        FLAKE_REF="$FLAKE"
      fi

      # ── Dry-build — validate config before applying anything ──────────
      log "Running dry-build to validate configuration..."
      if ! sudo nixos-rebuild dry-build --flake "$FLAKE_REF#$HOSTNAME" >> "$LOG_FILE" 2>&1; then
        log "ERROR: dry-build failed — configuration has errors, aborting"
        exit 1
      fi
      log "Dry-build passed — proceeding with rebuild"

      # ── Rebuild ────────────────────────────────────────────────────────
      log "Running nixos-rebuild switch..."
      if ! sudo nixos-rebuild switch --flake "$FLAKE_REF#$HOSTNAME" >> "$LOG_FILE" 2>&1; then
        log "ERROR: nixos-rebuild failed"
        if is_transient_error; then
          log "Transient error detected — retrying in 5 minutes..."
          sleep 300
          log "Retrying nixos-rebuild switch..."
          if sudo nixos-rebuild switch --flake "$FLAKE_REF#$HOSTNAME" >> "$LOG_FILE" 2>&1; then
            log "Rebuild succeeded on retry"
          else
            log "ERROR: rebuild failed again after retry"
            exit 1
          fi
        else
          exit 1
        fi
      fi

      # ── Primary: commit + push updated flake.lock ─────────────────────
      if [[ "$IS_PRIMARY" == "true" ]]; then
        if ! git -C "$NIXOS_CONFIG_PATH" diff --quiet flake.lock 2>/dev/null; then
          log "flake.lock updated — committing and pushing..."
          git -C "$NIXOS_CONFIG_PATH" add flake.lock
          git -C "$NIXOS_CONFIG_PATH" commit -m \
            "flake: auto-update nixpkgs ($(date +%Y-%m-%d))" 2>&1 | tee -a "$LOG_FILE"
          git -C "$NIXOS_CONFIG_PATH" push 2>&1 | tee -a "$LOG_FILE" || \
            log "WARN: push failed — other hosts won't get the nixpkgs update until manually pushed"
        else
          log "flake.lock unchanged — nixpkgs was already at latest"
        fi
      fi

      # ── Non-primary: record the rev we just built ─────────────────────
      # Use || true so a write failure (e.g. wrong user, unexpected permission)
      # never turns a successful rebuild into a reported failure.
      if [[ "$IS_PRIMARY" != "true" && -n "$REMOTE_REV" ]]; then
        if echo "$REMOTE_REV" > "$REV_FILE" 2>/dev/null; then
          log "Recorded rev ''${REMOTE_REV:0:8} to $REV_FILE"
        else
          log "WARN: could not write rev to $REV_FILE — next run will re-check"
        fi
      fi

      # ── Record timestamp ───────────────────────────────────────────────
      date +%s > "$TIMESTAMP_FILE" 2>/dev/null || \
        log "WARN: could not write timestamp to $TIMESTAMP_FILE"
      log "Update completed successfully"

      # ── Post-rebuild cleanup ───────────────────────────────────────────
      log "Cleaning up old generations (keep 30 days)..."
      sudo nix-collect-garbage --delete-older-than 30d >> "$LOG_FILE" 2>&1 || true

      log "Pruning old snapshots..."
      sudo snapper -c root cleanup timeline >> "$LOG_FILE" 2>&1 || true
      sudo snapper -c home cleanup timeline >> "$LOG_FILE" 2>&1 || true

      log "Checking for firmware updates..."
      if sudo fwupdmgr refresh >> "$LOG_FILE" 2>&1; then
        sudo fwupdmgr update --no-reboot-check >> "$LOG_FILE" 2>&1 || \
          log "No firmware updates available or update skipped"
      else
        log "fwupdmgr refresh failed — skipping firmware update"
      fi

      # ── Reboot notification ────────────────────────────────────────────
      if reboot_required; then
        log "Kernel update detected — reboot required"
        curl -s --max-time 10 \
          -H "Title: Reboot Required — $HOSTNAME" \
          -H "Priority: high" \
          -H "Tags: warning,arrows_counterclockwise" \
          -d "Kernel updated. Reboot when convenient. $(date '+%H:%M')" \
          "http://media-server:2586/nixos-updates" 2>/dev/null || true
        notify-send \
          --app-name "NixOS Update" \
          --icon "system-reboot" \
          --urgency critical \
          --expire-time 0 \
          "Reboot Required" \
          "A kernel update was applied. Please reboot when convenient." 2>/dev/null || true
      fi

      log "Done."
    '')
  ];

  # =========================================================================
  # Systemd user service — runs on session start
  #
  # Starts after the graphical session is ready, waits 2 minutes for the
  # desktop to settle, then calls nixos-auto-update.
  #
  # On isPrimary hosts: runs git pull + nix flake update + rebuild + push.
  # On other hosts: checks GitHub rev and rebuilds only if something changed.
  # =========================================================================
  systemd.user.services.nixos-auto-update = {
    description = "NixOS automatic update check";
    after    = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type         = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 120";
      ExecStart    = "${pkgs.bash}/bin/bash -c 'nixos-auto-update; OUTCOME=$?; if [ $OUTCOME -eq 0 ]; then sudo systemctl start notify-vault@success.service; elif [ $OUTCOME -eq 1 ]; then sudo systemctl start notify-vault@failure.service; fi'";
      Restart      = "no";
      TimeoutStartSec = "1h";
      Environment  = [ "PATH=/run/wrappers/bin:/run/current-system/sw/bin" ];
    };
    unitConfig = {
      ConditionPathExists = "!/run/user/%U/nixos-update-done";
    };
  };

  # =========================================================================
  # Mark update as done for this session — prevents re-running on relogin
  # =========================================================================
  systemd.user.services.nixos-auto-update-done = {
    description = "Mark NixOS update as done for this session";
    after       = [ "nixos-auto-update.service" ];
    wantedBy    = [ "nixos-auto-update.service" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/touch /run/user/%U/nixos-update-done";
    };
  };

  # =========================================================================
  # Sudo rules — NOPASSWD for update commands
  #
  # nixos-rebuild and nix-collect-garbage need root. All three family users
  # get these rules so auto-update works regardless of who is logged in.
  # =========================================================================
  security.sudo.extraRules = [
    {
      users    = [ "linuxury" "babylinux" "alex" ];
      commands = [
        { command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";       options = [ "NOPASSWD" ]; }
        { command = "${pkgs.nix}/bin/nix-collect-garbage";           options = [ "NOPASSWD" ]; }
        { command = "${pkgs.nix}/bin/nix";                           options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/nixos-rebuild";      options = [ "NOPASSWD" ]; }
        { command = "${pkgs.fwupd}/bin/fwupdmgr";                   options = [ "NOPASSWD" ]; }
        { command = "${pkgs.snapper}/bin/snapper";                   options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemd-inhibit";           options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/reboot";                    options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/reboot";             options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl start notify-vault@success.service"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl start notify-vault@failure.service"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  # =========================================================================
  # Log rotation
  # =========================================================================
  services.logrotate.settings.nixos-auto-update = {
    files     = "/var/log/nixos-auto-update.log";
    frequency = "monthly";
    rotate    = 3;
    compress  = true;
    missingok = true;
    notifempty = true;
  };

  }; # end config
}
