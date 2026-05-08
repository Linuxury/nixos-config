# ===========================================================================
# modules/base/syncthing-babylinux.nix — Syncthing for babylinux
#
# Imported by: Ryzen5800x, Asus-A15
#
# Runs as babylinux. Syncs her Obsidian vault and AI config between
# her own machines only (separate from linuxury's sync group).
#
# SETUP — after first rebuild on each new machine:
#   1. Get the Syncthing device ID:
#        systemctl status syncthing | grep "device id"
#      OR open the web UI at http://localhost:8384
#   2. Fill in the device ID below for that machine
#   3. Rebuild all her machines so they know each other's IDs
# ===========================================================================

{ ... }:

{
  services.syncthing = {
    enable    = true;
    user      = "babylinux";
    group     = "users";
    dataDir   = "/home/babylinux";
    configDir = "/home/babylinux/.config/syncthing";

    overrideDevices = true;
    overrideFolders = true;

    settings = {
      gui.address = "127.0.0.1:8384";

      # ── Devices ──────────────────────────────────────────────────────────
      # Collect device IDs after first boot of each machine:
      #   systemctl status syncthing | grep "device id"
      devices = {
        "Ryzen5800x" = {
          id        = "FILL-IN-RYZEN5800X-BABYLINUX-SYNCTHING-ID";
          addresses = [ "tcp://100.114.95.99:22000" ];
        };
        "Asus-A15" = {
          id        = "FILL-IN-ASUS-A15-BABYLINUX-SYNCTHING-ID";
          addresses = [ "tcp://FILL-IN-ASUS-A15-TAILSCALE-IP:22000" ];
        };
      };

      # ── Folders ──────────────────────────────────────────────────────────
      # Folder IDs use a babylinux suffix to avoid any clash with
      # linuxury's "obsidian" / "ai-config" folder IDs.
      folders = {
        "Obsidian" = {
          id               = "obsidian-babylinux";
          label            = "Obsidian Vault";
          path             = "/home/babylinux/Obsidian";
          devices          = [ "Ryzen5800x" "Asus-A15" ];
          fsWatcherEnabled = true;
          fsWatcherDelayS  = 10;
          rescanIntervalS  = 60;
          ignorePerms      = false;
        };

        "ai-config" = {
          id               = "ai-config-babylinux";
          label            = "AI Config";
          path             = "/home/babylinux/.agents";
          devices          = [ "Ryzen5800x" "Asus-A15" ];
          fsWatcherEnabled = true;
          fsWatcherDelayS  = 10;
          rescanIntervalS  = 60;
          ignorePerms      = false;
        };
      };

      options = {
        localAnnounceEnabled = true;
        relaysEnabled        = false;
        urAccepted           = -1;
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 21027 ];
  };
}
