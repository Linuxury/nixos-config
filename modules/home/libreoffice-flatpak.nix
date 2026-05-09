# ===========================================================================
# modules/home/libreoffice-flatpak.nix — LibreOffice via Flathub
#
# Imported by: users/babylinux/home.nix
#
# Installs LibreOffice from Flathub on first login instead of nixpkgs.
# The nixpkgs build compiles from source (~400 MB download, 40+ min rebuild
# on every dep bump). The Flatpak version is a pre-built binary that only
# re-downloads on actual LibreOffice releases, and updates are delta-based.
#
# Requires: services.flatpak.enable = true and Flathub system remote
#           (both provided by graphical-base.nix).
#
# Spell-check dictionaries are bundled in the LibreOffice Flatpak — no
# separate hunspell packages needed.
# ===========================================================================

{ pkgs, ... }:

{
  systemd.user.services.libreoffice-flatpak-install = {
    Unit = {
      Description         = "Install LibreOffice from Flathub";
      After               = [ "graphical-session.target" "network-online.target" ];
      Wants               = [ "graphical-session.target" "network-online.target" ];
      ConditionPathExists = "!%h/.local/share/flatpak/app/org.libreoffice.LibreOffice";
    };

    Service = {
      Type    = "oneshot";
      Restart = "no";
      ExecStart = "${pkgs.writeShellScript "install-libreoffice" ''
        FLATPAK="${pkgs.flatpak}/bin/flatpak"

        if $FLATPAK info --user org.libreoffice.LibreOffice &>/dev/null; then
          echo "LibreOffice already installed, skipping."
          exit 0
        fi

        echo "Installing LibreOffice from Flathub..."
        if $FLATPAK install --user --noninteractive flathub org.libreoffice.LibreOffice; then
          echo "LibreOffice installed successfully."
        else
          echo "ERROR: LibreOffice install failed. Check journalctl --user -u libreoffice-flatpak-install"
          exit 1
        fi
      ''}";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
