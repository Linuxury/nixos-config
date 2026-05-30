# ===========================================================================
# modules/base/libreoffice.nix — LibreOffice via Flathub (system-wide)
#
# Imported by: graphical-base.nix (all graphical hosts)
#
# Creates a systemd user service that installs LibreOffice from Flathub on
# first login for every user on every graphical host. This avoids the 40+
# minute nixpkgs rebuild cost (source-compiled, ~400 MB per dep bump).
#
# Gracefully skips if:
#   - LibreOffice is already installed
#   - Flathub remote is not available (e.g. Alex's machines where all
#     system remotes are wiped for child safety)
#
# Requires: services.flatpak.enable = true and Flathub system remote
#           (both provided by graphical-base.nix).
# ===========================================================================

{ pkgs, ... }:

{
  systemd.user.services.libreoffice-flatpak-install = {
    description         = "Install LibreOffice from Flathub";
    after               = [ "graphical-session.target" "network-online.target" ];
    wants               = [ "graphical-session.target" "network-online.target" ];
    unitConfig.ConditionPathExists =
      "!%h/.local/share/flatpak/app/org.libreoffice.LibreOffice";
    serviceConfig = {
      Type    = "oneshot";
      Restart = "no";
      ExecStart = pkgs.writeShellScript "install-libreoffice" ''
        FLATPAK="${pkgs.flatpak}/bin/flatpak"

        # Skip gracefully on hosts where Flathub has been removed (e.g. Alex's machines)
        if ! $FLATPAK remote-list --system 2>/dev/null | grep -q flathub; then
          echo "Flathub remote not available, skipping LibreOffice install."
          exit 0
        fi

        if $FLATPAK info --user org.libreoffice.LibreOffice &>/dev/null; then
          echo "LibreOffice already installed, skipping."
          exit 0
        fi

        echo "Installing LibreOffice from Flathub..."
        if $FLATPAK install --user --noninteractive flathub org.libreoffice.LibreOffice; then
          echo "LibreOffice installed successfully."
        else
          echo "ERROR: LibreOffice install failed. Check: journalctl --user -u libreoffice-flatpak-install"
          exit 1
        fi
      '';
    };
    wantedBy = [ "graphical-session.target" ];
  };
}
