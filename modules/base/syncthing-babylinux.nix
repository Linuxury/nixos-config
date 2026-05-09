# ===========================================================================
# modules/base/syncthing-babylinux.nix — Syncthing for babylinux
#
# Imported by: Ryzen5800x, Asus-A15
#
# Runs as babylinux. Participates in the same single Obsidian sync group
# as all other hosts — folder ID "obsidian" matches syncthing.nix.
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

      # ── Devices — IDs verified 2026-05-09 ───────────────────────────────
      devices = {
        "Ryzen5800x" = {
          id        = "KMIXV62-XWKZX73-I4D5TVY-QD4NQ5D-S4B4LSO-TGVU7V5-267HUAB-YDEGXQG";
          addresses = [ "tcp://100.114.95.99:22000" ];
        };
        # Asus-A15 — add when machine is online and ID is obtained:
        #   systemctl status syncthing | grep "device id"
        # "Asus-A15" = {
        #   id        = "FILL-IN-ASUS-A15-BABYLINUX-SYNCTHING-ID";
        #   addresses = [ "tcp://FILL-IN-ASUS-A15-TAILSCALE-IP:22000" ];
        # };
        "Ryzen5900x" = {
          id        = "NOWQCM4-GKSAUGA-PWPLLPX-WPUWSD4-DOXLHTJ-QQ2GTVV-CE3IAKR-B5LWZAI";
          addresses = [ "tcp://100.112.137.120:22000" ];
        };
        "ThinkPad" = {
          id        = "INWQLVH-KBFFJLJ-YAPK7JQ-BLUEJNL-GMHVIMO-YX3G5JZ-PO2FMHS-MROBVAU";
          addresses = [ "tcp://100.125.106.128:22000" ];
        };
        "Media-Server" = {
          id        = "AUUN6PE-UYNWKLZ-UGUUERI-MQTIANQ-LMUG2SC-P3C5GFR-ODARYQP-WMMWTQD";
          addresses = [ "tcp://100.116.205.39:22000" ];
        };
        "MinisForum" = {
          id        = "PZEK3RM-6YSY3EP-CL4Y2CI-O3BLPTA-CWUXGPH-XL4GMDP-4BIOMZ7-NE3WUAM";
          addresses = [ "tcp://100.126.220.53:22000" ];
        };
        "Radxa-X4" = {
          id        = "BGJEXC3-YNHVMOF-PAG2C43-5C3GI33-TTNMFCF-D5BSZL6-IXMN56R-BY7N5QH";
          addresses = [ "tcp://100.107.245.87:22000" ];
        };
        "Pixel-Pro-8" = {
          id        = "DHN7MUP-UBRZGR4-PXHDLCY-54O2IJI-Q7K7WKH-QQMQZWV-SXLAVNV-ALFCQQI";
          addresses = [ "tcp://100.126.77.126:22000" ];
        };
      };

      # ── Folders ──────────────────────────────────────────────────────────
      folders = {
        "Obsidian" = {
          id               = "obsidian";
          label            = "Obsidian Vault";
          path             = "/home/babylinux/Obsidian";
          devices          = [
            "Ryzen5800x"
            # "Asus-A15"  # add back once ID is filled in above
            "Ryzen5900x" "ThinkPad" "Media-Server" "MinisForum" "Radxa-X4"
            "Pixel-Pro-8"
          ];
          fsWatcherEnabled = true;
          fsWatcherDelayS  = 10;
          rescanIntervalS  = 60;
          ignorePerms      = false;
        };

        "ai-config" = {
          id               = "ai-config-babylinux";
          label            = "AI Config";
          path             = "/home/babylinux/.agents";
          devices          = [ "Ryzen5800x" ]; # Asus-A15 added once ID is known
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
