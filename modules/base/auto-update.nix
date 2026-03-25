# ===========================================================================
# modules/base/auto-update.nix — Automatic System Updates
#
# Handles automatic NixOS updates for desktop and laptop machines.
# Servers use their own simpler system.autoUpgrade setup.
#
# How it works:
#   1. A systemd service runs after the graphical session starts
#   2. It checks when the last successful update happened
#   3. If more than 7 days ago → runs flake update + nixos-rebuild
#   4. notify-update-result.sh handles all notifications:
#      - Obsidian vault entries (success + failure)
#      - Desktop toast (success + failure)
#      - Email via msmtp (failure only)
#   5. If a reboot is required after a kernel update, a persistent
#      notification appears — you decide when to reboot
#
# Weekly schedule (system.autoUpgrade):
#   - Saturday 3am via systemd timer
#   - onFailure/onSuccess hooks trigger notify-update-result.sh
#   - Missed runs (machine was off) caught on next boot via session service
#
# To disable on a specific host:
#   services.nixos-auto-update.enable = lib.mkForce false;
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  # ---------------------------------------------------------------------------
  # Notification script — shared handler for all update notifications
  # Writes Obsidian entries, sends toast, emails on failure
  # ---------------------------------------------------------------------------
  notifyScript = ./scripts/notify-update-result.sh;
in

{
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

  # SMTP password via agenix — only hosts that import this module need it
  age.secrets.smtp-app-password = {
    file = ../../secrets/smtp-app-password.age;
    mode = "0400";
    owner = "root";
  };

  # =========================================================================
  # Scheduled weekly update
  #
  # This handles machines that are always on.
  # Runs nix flake update + nixos-rebuild switch every week.
  # allowReboot is false — we handle reboot notifications ourselves.
  # =========================================================================
  system.autoUpgrade = {
    enable      = true;
    flake        = "github:linuxury/nixos-config";
    # No --update-input: servers use flake.lock from the repo.
    # Update nixpkgs from an admin machine with `nru`, then push.
    dates        = "Sat 03:00"; # Saturday 3am — captures full week of upstream releases
    allowReboot  = false;
    # Up to 45min random delay so all 9 machines don't hit GitHub at once
    randomizedDelaySec = "45min";
  };

  # =========================================================================
  # Weekly schedule notification hooks
  #
  # system.autoUpgrade has no built-in hooks. These systemd overrides
  # trigger our notification handler when the weekly update succeeds or fails.
  # =========================================================================
  systemd.services.notify-upgrade-success = {
    description = "Notify on weekly NixOS upgrade success";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${notifyScript} success /var/log/nixos-auto-update.log";
    };
  };

  systemd.services.notify-upgrade-failure = {
    description = "Notify on weekly NixOS upgrade failure";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${notifyScript} failure /var/log/nixos-auto-update.log";
    };
  };

  # Wire to nixos-upgrade.service (created by system.autoUpgrade)
  systemd.services.nixos-upgrade.onSuccess = [ "notify-upgrade-success.service" ];
  systemd.services.nixos-upgrade.onFailure = [ "notify-upgrade-failure.service" ];

  # =========================================================================
  # Last update timestamp tracking
  #
  # Every time a successful update runs we write the current timestamp
  # to this file. The session-start service reads it to decide whether
  # an update is needed.
  # =========================================================================
  environment.etc."nixos-last-update".text = "";

  # =========================================================================
  # Update script
  #
  # This script does the actual work:
  #   1. Checks if update is needed (> 7 days since last)
  #   2. Runs dry-build first (catches eval errors without applying)
  #   3. Updates flake inputs
  #   4. Rebuilds the system
  #   5. On transient errors (timeout/network), retries once after 5min
  #   6. Records the timestamp
  #   7. Notifies via shared handler (Obsidian + toast + email)
  #   8. Checks if a reboot is needed and notifies persistently
  # =========================================================================
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "nixos-auto-update" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # -----------------------------------------------------------------------
      # Arguments
      # -----------------------------------------------------------------------
      FORCE=false
      case "''${1:-}" in
        --force|-f) FORCE=true ;;
        --help|-h)
          echo "Usage: nixos-auto-update [--force]"
          echo ""
          echo "  --force, -f   Bypass 7-day check, update immediately"
          echo "  --help, -h    Show this help"
          exit 0
          ;;
      esac

      # -----------------------------------------------------------------------
      # Configuration
      # -----------------------------------------------------------------------
      TIMESTAMP_FILE="/etc/nixos-last-update-time"
      MAX_DAYS=7
      FLAKE="github:linuxury/nixos-config"
      HOSTNAME=$(hostname)
      LOG_FILE="/var/log/nixos-auto-update.log"
      NOTIFY="${notifyScript}"

      # -----------------------------------------------------------------------
      # Logging helper
      # -----------------------------------------------------------------------
      log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
      }

      # -----------------------------------------------------------------------
      # Check if update is needed
      # Reads last update timestamp and compares to today
      # -----------------------------------------------------------------------
      needs_update() {
        if [ ! -f "$TIMESTAMP_FILE" ]; then
          log "No timestamp file found — first run, update needed"
          return 0  # No record = needs update
        fi

        last_update=$(cat "$TIMESTAMP_FILE")
        now=$(date +%s)
        diff_days=$(( (now - last_update) / 86400 ))

        log "Last update: $diff_days days ago"

        if [ "$diff_days" -ge "$MAX_DAYS" ]; then
          log "More than $MAX_DAYS days since last update — update needed"
          return 0
        else
          log "Last update was $diff_days days ago — no update needed"
          return 1
        fi
      }

      # -----------------------------------------------------------------------
      # Check if a reboot is required
      # Compares running kernel to installed kernel
      # -----------------------------------------------------------------------
      reboot_required() {
        current_kernel=$(uname -r)
        installed_kernel=$(ls /run/current-system/kernel-modules/lib/modules/ 2>/dev/null | head -1)

        if [ -n "$installed_kernel" ] && [ "$current_kernel" != "$installed_kernel" ]; then
          return 0  # Reboot needed
        fi
        return 1  # No reboot needed
      }

      # -----------------------------------------------------------------------
      # Check if error is transient (timeout, network)
      # -----------------------------------------------------------------------
      is_transient_error() {
        grep -qiE "timed out|timeout|connection refused|couldn't connect|network" "$LOG_FILE" 2>/dev/null
      }

      # -----------------------------------------------------------------------
      # Main update logic
      # -----------------------------------------------------------------------
      if [ "$FORCE" = true ]; then
        log "Force flag set — bypassing 7-day check"
      elif ! needs_update; then
        exit 0
      fi

      log "Starting NixOS system update..."

      # Notify user that update is starting
      notify-send \
        --app-name "NixOS Update" \
        --icon "system-software-update" \
        --urgency normal \
        "NixOS Update Starting" \
        "Updating flake inputs and rebuilding system in the background..." 2>/dev/null || true

      # -----------------------------------------------------------------------
      # Dry-build first — catches eval errors without applying anything
      # -----------------------------------------------------------------------
      log "Running dry-build to validate configuration..."
      if ! sudo nixos-rebuild dry-build --flake "$FLAKE#$HOSTNAME" >> "$LOG_FILE" 2>&1; then
        log "ERROR: dry-build failed — configuration has errors"
        bash "$NOTIFY" failure "$LOG_FILE"
        exit 1
      fi
      log "Dry-build passed — proceeding with update"

      # -----------------------------------------------------------------------
      # Update flake inputs
      # -----------------------------------------------------------------------
      log "Updating flake inputs..."
      if ! sudo nix flake update "$FLAKE" >> "$LOG_FILE" 2>&1; then
        log "ERROR: flake update failed"

        # Retry on transient errors
        if is_transient_error; then
          log "Transient error detected — retrying flake update in 5 minutes..."
          sleep 300
          log "Retrying flake update..."
          if sudo nix flake update "$FLAKE" >> "$LOG_FILE" 2>&1; then
            log "Flake update succeeded on retry"
          else
            log "ERROR: flake update failed again after retry"
            bash "$NOTIFY" failure "$LOG_FILE"
            exit 1
          fi
        else
          bash "$NOTIFY" failure "$LOG_FILE"
          exit 1
        fi
      fi

      # -----------------------------------------------------------------------
      # Rebuild system
      # -----------------------------------------------------------------------
      log "Running nixos-rebuild switch..."
      if ! sudo nixos-rebuild switch --flake "$FLAKE#$HOSTNAME" >> "$LOG_FILE" 2>&1; then
        log "ERROR: nixos-rebuild failed"

        # Retry on transient errors
        if is_transient_error; then
          log "Transient error detected — retrying rebuild in 5 minutes..."
          sleep 300
          log "Retrying nixos-rebuild switch..."
          if sudo nixos-rebuild switch --flake "$FLAKE#$HOSTNAME" >> "$LOG_FILE" 2>&1; then
            log "Rebuild succeeded on retry"
          else
            log "ERROR: rebuild failed again after retry"
            bash "$NOTIFY" failure "$LOG_FILE"
            exit 1
          fi
        else
          bash "$NOTIFY" failure "$LOG_FILE"
          exit 1
        fi
      fi

      # -----------------------------------------------------------------------
      # Success path
      # -----------------------------------------------------------------------
      # Record successful update timestamp
      date +%s | sudo tee "$TIMESTAMP_FILE" > /dev/null
      log "Update completed successfully"

      # Garbage collect old generations (keep last 30 days)
      log "Cleaning up old generations..."
      sudo nix-collect-garbage --delete-older-than 30d >> "$LOG_FILE" 2>&1 || true

      # Firmware updates via fwupd
      log "Checking for firmware updates..."
      if sudo fwupdmgr refresh >> "$LOG_FILE" 2>&1; then
        sudo fwupdmgr update --no-reboot-check >> "$LOG_FILE" 2>&1 || \
          log "No firmware updates available or update skipped"
      else
        log "fwupdmgr refresh failed — skipping firmware update"
      fi

      # Notify success via shared handler
      bash "$NOTIFY" success "$LOG_FILE"

      # Check if reboot is required
      if reboot_required; then
        log "Kernel update detected — reboot required"
        # Persistent notification — stays until dismissed
        notify-send \
          --app-name "NixOS Update" \
          --icon "system-reboot" \
          --urgency critical \
          --expire-time 0 \
          "Reboot Required" \
          "A kernel update was applied. Please reboot when convenient to complete the update." 2>/dev/null || true
      fi

      log "Done."
    '')
  ];

  # =========================================================================
  # Systemd user service — runs on session start
  #
  # This service starts after the graphical session is ready,
  # waits a short delay so the desktop is fully loaded, then
  # checks if an update is needed and runs one if so.
  #
  # Running as a user service means:
  #   - notify-send works correctly (has access to the user's display)
  #   - It starts after login, not at boot
  #   - One instance per user session
  # =========================================================================
  systemd.user.services.nixos-auto-update = {
    description = "NixOS automatic update check";

    # Start after the graphical session is ready
    after    = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];

    serviceConfig = {
      Type      = "oneshot";
      # Wait 2 minutes after session start before checking
      # Gives the DE time to fully load and settle
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 120";
      ExecStart    = "${pkgs.bash}/bin/bash -c 'nixos-auto-update'";

      # Don't restart if it fails — wait for next session
      Restart     = "no";

      # Give it enough time to complete a full update
      TimeoutStartSec = "1h";
    };

    # Only run once per session, not on every restart
    unitConfig = {
      # If the service has already succeeded this session, don't run again
      ConditionPathExists = "!/run/user/%U/nixos-update-done";
    };
  };

  # =========================================================================
  # Create a marker file when update service completes successfully
  # Prevents running more than once per session
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
  # Sudo rules for update script
  #
  # The update script needs sudo for nixos-rebuild and nix-collect-garbage.
  # These specific rules allow the script to run those commands without
  # prompting for a password during the automated update.
  # =========================================================================
  security.sudo.extraRules = [
    {
      # All three family users — NOPASSWD only for these specific update
      # commands, not general sudo. Alex is not in wheel but still needs
      # the auto-update service to work on his machines.
      users    = [ "linuxury" "babylinux" "alex" ];
      commands = [
        {
          command  = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
          options  = [ "NOPASSWD" ];
        }
        {
          command  = "${pkgs.nix}/bin/nix-collect-garbage";
          options  = [ "NOPASSWD" ];
        }
        {
          command  = "${pkgs.nix}/bin/nix";
          options  = [ "NOPASSWD" ];
        }
        {
          command  = "/run/current-system/sw/bin/nixos-rebuild";
          options  = [ "NOPASSWD" ];
        }
        {
          command  = "${pkgs.fwupd}/bin/fwupdmgr";
          options  = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # =========================================================================
  # Log rotation for update log
  # Keeps logs from growing indefinitely
  # =========================================================================
  services.logrotate.settings.nixos-auto-update = {
    files        = "/var/log/nixos-auto-update.log";
    frequency    = "monthly";
    rotate       = 3;
    compress     = true;
    missingok    = true;
    notifempty   = true;
  };
}
