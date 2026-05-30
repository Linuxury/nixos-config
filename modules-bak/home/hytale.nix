# ===========================================================================
# modules/home/hytale.nix — Hytale launcher: auto-install + flatpak overrides
#
# Handles everything Hytale-related for a Home Manager user:
#   - Installs from bundled flatpak on first login (symlinked from assets repo)
#   - Optional CDN fallback (linuxury only — downloads if local bundle missing)
#   - Flatpak overrides applied on every rebuild:
#       ELECTRON_OZONE_PLATFORM_HINT=x11  (prevents blank window on COSMIC/MangoWC)
#       --device=input                    (controller support)
#
# Usage (in user home.nix):
#   imports = [ ../../modules/home/hytale.nix ];
#   programs.hytale.enable = true;
#
# For CDN fallback (linuxury — downloads from Hytale CDN if bundle not found):
#   programs.hytale.cdnFallback = true;
#
# When Hytale lands on Flathub:
#   1. Replace the service with a proper flatpak declaration
#   2. Keep the activation override (Wayland + controller)
#   3. Remove this module
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  cfg = config.programs.hytale;
in

{
  options.programs.hytale = {
    enable = lib.mkEnableOption "Hytale launcher auto-install and flatpak overrides";

    cdnFallback = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = ''
        Download the Hytale flatpak from the official CDN if the local bundle
        is not found. Requires network access at login. Intended for linuxury
        only — babylinux and alex always use the bundled file from the assets repo.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # =========================================================================
    # Bundle path — ~/Documents/assets/flatpaks/hytale-launcher-latest.flatpak
    #
    # Non-CDN users (babylinux, alex): symlink to nixos-config assets repo.
    # CDN users (linuxury): plain dir created by the activation below so the
    # downloaded file has a writable home (can't symlink into the git repo).
    # =========================================================================
    home.file = lib.mkIf (!cfg.cdnFallback) {
      "Documents/assets/flatpaks".source =
        config.lib.file.mkOutOfStoreSymlink
          "${config.home.homeDirectory}/nixos-config/assets/flatpaks";
    };

    home.activation.hytale-flatpak-dir = lib.mkIf cfg.cdnFallback
      (lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        mkdir -p "$HOME/Documents/assets/flatpaks"
      '');

    # =========================================================================
    # Install service — runs once on first login after graphical session starts
    #
    # ConditionPathExists ensures it only runs when Hytale is not yet installed.
    # After install the service is a no-op on all subsequent logins.
    # =========================================================================
    systemd.user.services.hytale-flatpak-install = {
      Unit = {
        Description         = "Install Hytale launcher from bundled flatpak";
        After               = [ "graphical-session.target" ]
          ++ lib.optionals cfg.cdnFallback [ "network-online.target" ];
        Wants               = [ "graphical-session.target" ]
          ++ lib.optionals cfg.cdnFallback [ "network-online.target" ];
        ConditionPathExists = "!%h/.local/share/flatpak/app/com.hypixel.HytaleLauncher";
      };

      Service = {
        Type    = "oneshot";
        Restart = "no";
        ExecStart = "${pkgs.writeShellScript "install-hytale" (
          ''
            FLATPAK="${pkgs.flatpak}/bin/flatpak"
            FLATPAK_FILE="$HOME/Documents/assets/flatpaks/hytale-launcher-latest.flatpak"
          ''
          + lib.optionalString cfg.cdnFallback ''
            CURL="${pkgs.curl}/bin/curl"
            HYTALE_URL="https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak"
          ''
          + ''

            if $FLATPAK info --user com.hypixel.HytaleLauncher &>/dev/null; then
              echo "Hytale already installed, skipping."
              exit 0
            fi

            # Ensure Flathub is available for runtime dependencies
            $FLATPAK remote-add --user --if-not-exists flathub \
              https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

          ''
          + lib.optionalString cfg.cdnFallback ''
            if [ ! -f "$FLATPAK_FILE" ]; then
              echo "Local bundle not found — downloading from $HYTALE_URL"
              mkdir -p "$(dirname "$FLATPAK_FILE")"
              if ! $CURL -L --fail -o "$FLATPAK_FILE" "$HYTALE_URL"; then
                echo "ERROR: Could not download Hytale. Check internet or clone the assets repo."
                exit 1
              fi
            fi

          ''
          + lib.optionalString (!cfg.cdnFallback) ''
            if [ ! -f "$FLATPAK_FILE" ]; then
              echo "ERROR: Hytale flatpak not found at $FLATPAK_FILE"
              echo "  Place hytale-launcher-latest.flatpak in ~/nixos-config/assets/flatpaks/ and rebuild."
              exit 1
            fi

          ''
          + ''
            echo "Installing Hytale launcher..."
            $FLATPAK install --user --noninteractive "$FLATPAK_FILE" || true

            # Remove the sideload origin remote — it has no appstream data and
            # causes COSMIC Store's flatpak-user backend to fail on load.
            $FLATPAK remote-delete --user --force hytalelauncher-origin 2>/dev/null || true

            if $FLATPAK info --user com.hypixel.HytaleLauncher &>/dev/null; then
              echo "Hytale installed successfully."
            else
              echo "ERROR: Hytale install failed. Check journalctl --user -u hytale-flatpak-install"
              exit 1
            fi
          ''
        )}";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    # =========================================================================
    # Flatpak overrides — applied on every HM rebuild (idempotent)
    #
    # ELECTRON_OZONE_PLATFORM_HINT=x11: forces XWayland mode so Hytale's
    #   Electron renderer doesn't use native Wayland GPU paths that produce
    #   a blank window on COSMIC and MangoWC.
    # --device=input: grants access to input devices for controller support.
    # =========================================================================
    home.activation.hytale-overrides = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.flatpak}/bin/flatpak override --user \
        --env=ELECTRON_OZONE_PLATFORM_HINT=x11 \
        --device=input \
        com.hypixel.HytaleLauncher 2>/dev/null || true
    '';
  };
}
