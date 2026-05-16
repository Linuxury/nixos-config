# ===========================================================================
# modules/base/fluxer.nix — Fluxer via Flathub (system-wide)
#
# Imported by: graphical-base.nix (all graphical hosts)
#
# Creates a systemd user service that installs Fluxer from Flathub on
# first login for every user on every graphical host.
#
# Fluxer is a self-hostable community/messaging platform replacing Discord.
# Install it from Flathub — no nixpkgs derivation exists.
#
# Gracefully skips if:
#   - Fluxer is already installed
#   - Flathub remote is not available (e.g. Alex's machines where all
#     system remotes are wiped for child safety)
#
# Requires: services.flatpak.enable = true and Flathub system remote
#           (both provided by graphical-base.nix).
# ===========================================================================

{ pkgs, ... }:

{
  systemd.user.services.fluxer-flatpak-install = {
    description         = "Install Fluxer from Flathub";
    after               = [ "graphical-session.target" "network-online.target" ];
    wants               = [ "graphical-session.target" "network-online.target" ];
    unitConfig.ConditionPathExists =
      "!%h/.local/share/flatpak/app/app.fluxer.Fluxer";
    serviceConfig = {
      Type    = "oneshot";
      Restart = "no";
      ExecStart = pkgs.writeShellScript "install-fluxer" ''
        FLATPAK="${pkgs.flatpak}/bin/flatpak"

        # Skip gracefully on hosts where Flathub has been removed (e.g. Alex's machines)
        if ! $FLATPAK remote-list --system 2>/dev/null | grep -q flathub; then
          echo "Flathub remote not available, skipping Fluxer install."
          exit 0
        fi

        if $FLATPAK info --user app.fluxer.Fluxer &>/dev/null; then
          echo "Fluxer already installed, skipping."
          exit 0
        fi

        echo "Installing Fluxer from Flathub..."
        if $FLATPAK install --user --noninteractive flathub app.fluxer.Fluxer; then
          echo "Fluxer installed successfully."
        else
          echo "ERROR: Fluxer install failed. Check: journalctl --user -u fluxer-flatpak-install"
          exit 1
        fi
      '';
    };
    wantedBy = [ "graphical-session.target" ];
  };
}
