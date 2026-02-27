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
#   4. notify-send reports status to whatever notification daemon
#      is running (COSMIC, KDE, or dunst in WM sessions)
#   5. If a reboot is required after a kernel update, a persistent
#      notification appears — you decide when to reboot
#
# Scheduled updates:
#   - Weekly via system.autoUpgrade (catches machines that are always on)
#   - On session start via systemd service (catches missed updates if
#     machine was off on the scheduled day)
#
# To disable on a specific host:
#   services.nixos-auto-update.enable = lib.mkForce false;
# ===========================================================================

{ config, pkgs, lib, ... }:

{
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
    flags        = [ "--update-input" "nixpkgs" ];
    dates        = "Sat 03:00"; # Saturday 3am — captures full week of upstream releases
    allowReboot  = false;
    # Up to 45min random delay so all 9 machines don't hit GitHub at once
    randomizedDelaySec = "45min";
  };

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
  #   1. Sends a start notification
  #   2. Updates flake inputs
  #   3. Rebuilds the system
  #   4. Records the timestamp
  #   5. Notifies success or failure
  #   6. Checks if a reboot is needed and notifies persistently
  # =========================================================================
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "nixos-auto-update" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # -----------------------------------------------------------------------
      # Configuration
      # -----------------------------------------------------------------------
      TIMESTAMP_FILE="/etc/nixos-last-update-time"
      MAX_DAYS=7
      FLAKE="github:linuxury/nixos-config"
      HOSTNAME=$(hostname)
      LOG_FILE="/var/log/nixos-auto-update.log"

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
      # Main update logic
      # -----------------------------------------------------------------------
      if ! needs_update; then
        exit 0
      fi

      log "Starting NixOS system update..."

      # Notify user that update is starting
      notify-send \
        --app-name "NixOS Update" \
        --icon "system-software-update" \
        --urgency normal \
        "NixOS Update Starting" \
        "Updating flake inputs and rebuilding system in the background..."

      # Update flake inputs
      log "Updating flake inputs..."
      if ! sudo nix flake update "$FLAKE" >> "$LOG_FILE" 2>&1; then
        log "ERROR: flake update failed"
        notify-send \
          --app-name "NixOS Update" \
          --icon "dialog-error" \
          --urgency critical \
          "NixOS Update Failed" \
          "Flake update failed. Check /var/log/nixos-auto-update.log for details."
        exit 1
      fi

      # Rebuild system
      log "Running nixos-rebuild switch..."
      if ! sudo nixos-rebuild switch --flake "$FLAKE#$HOSTNAME" >> "$LOG_FILE" 2>&1; then
        log "ERROR: nixos-rebuild failed"
        notify-send \
          --app-name "NixOS Update" \
          --icon "dialog-error" \
          --urgency critical \
          "NixOS Update Failed" \
          "System rebuild failed. Check /var/log/nixos-auto-update.log for details."
        exit 1
      fi

      # Record successful update timestamp
      date +%s | sudo tee "$TIMESTAMP_FILE" > /dev/null
      log "Update completed successfully"

      # Garbage collect old generations (keep last 30 days)
      log "Cleaning up old generations..."
      sudo nix-collect-garbage --delete-older-than 30d >> "$LOG_FILE" 2>&1 || true

      # Notify success
      notify-send \
        --app-name "NixOS Update" \
        --icon "system-software-update" \
        --urgency normal \
        "NixOS Update Complete" \
        "System successfully updated. $(date '+%A, %B %d at %H:%M')"

      # Check if reboot is required
      if reboot_required; then
        log "Kernel update detected — reboot required"
        # Persistent notification — stays until dismissed
        # urgency=critical means it won't auto-dismiss in most DEs
        notify-send \
          --app-name "NixOS Update" \
          --icon "system-reboot" \
          --urgency critical \
          --expire-time 0 \
          "Reboot Required" \
          "A kernel update was applied. Please reboot when convenient to complete the update."
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
