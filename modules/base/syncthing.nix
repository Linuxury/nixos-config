# ===========================================================================
# modules/base/syncthing.nix — Syncthing file sync (all hosts)
#
# Imported by: all 9 hosts + phone
#
# Fully declarative Syncthing config — devices and folders hardcoded.
# No web UI setup needed after rebuild. Syncthing auto-pairs and syncs.
#
# The shared folder is ~/Obsidian — the vault that tracks host updates,
# research, activity logs, and project history. Syncthing keeps it in
# sync across all machines. Git backup runs on Ryzen5900x only.
#
# Device IDs generated fresh 2026-03-25 — no legacy config carried over.
# Phone (Pixel Pro 8) ID obtained from Syncthing-Fork app.
# ===========================================================================

{ ... }:

{
  services.syncthing = {
    enable    = true;
    user      = "linuxury";
    group     = "users";
    dataDir   = "/home/linuxury";
    configDir = "/home/linuxury/.config/syncthing";

    # Nix is the source of truth — any device/folder not listed here gets
    # removed from Syncthing's config on rebuild.
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      # ── GUI ────────────────────────────────────────────────────────────
      gui = {
        address = "127.0.0.1:8384";
      };

      # ── Devices ────────────────────────────────────────────────────────
      # Each device gets a fresh identity. Tailscale IPs force direct
      # connections instead of relays. Placeholders marked FILL-IN are
      # for hosts that were offline when IDs were generated.
      devices = {
        "Ryzen5900x" = {
          id = "NOWQCM4-GKSAUGA-PWPLLPX-WPUWSD4-DOXLHTJ-QQ2GTVV-CE3IAKR-B5LWZAI";
          addresses = [ "tcp://100.112.137.120:22000" ];
        };

        "ThinkPad" = {
          id = "FILL-IN-THINKPAD-DEVICE-ID";
          addresses = [ "tcp://100.125.106.128:22000" ];
        };

        "Media-Server" = {
          id = "AUUN6PE-UYNWKLZ-UGUUERI-MQTIANQ-LMUG2SC-P3C5GFR-ODARYQP-WMMWTQD";
          addresses = [ "tcp://100.116.205.39:22000" ];
        };

        "MinisForum" = {
          id = "PZEK3RM-6YSY3EP-CL4Y2CI-O3BLPTA-CWUXGPH-XL4GMDP-4BIOMZ7-NE3WUAM";
          addresses = [ "tcp://100.126.220.53:22000" ];
        };

        "Radxa-X4" = {
          id = "BGJEXC3-YNHVMOF-PAG2C43-5C3GI33-TTNMFCF-D5BSZL6-IXMN56R-BY7N5QH";
          addresses = [ "tcp://100.107.245.87:22000" ];
        };

        "Alex-Desktop" = {
          id = "FILL-IN-ALEX-DESKTOP-DEVICE-ID";
          addresses = [ "tcp://FILL-IN-ALEX-DESKTOP-IP:22000" ];
        };

        "Alex-Laptop" = {
          id = "FILL-IN-ALEX-LAPTOP-DEVICE-ID";
          addresses = [ "tcp://FILL-IN-ALEX-LAPTOP-IP:22000" ];
        };

        "Asus-A15" = {
          id = "FILL-IN-ASUS-A15-DEVICE-ID";
          addresses = [ "tcp://FILL-IN-ASUS-A15-IP:22000" ];
        };

        "Ryzen5800x" = {
          id = "FILL-IN-RYZEN5800X-DEVICE-ID";
          addresses = [ "tcp://FILL-IN-RYZEN5800X-IP:22000" ];
        };

        "Pixel-Pro-8" = {
          id = "DHN7MUP-UBRZGR4-PXHDLCY-54O2IJI-Q7K7WKH-QQMQZWV-SXLAVNV-ALFCQQI";
          addresses = [ "tcp://100.126.77.126:22000" ];
        };
      };

      # ── Folders ────────────────────────────────────────────────────────
      # Single shared folder — the Obsidian vault. Devices with valid IDs
      # are listed here. FILL-IN devices are added when their IDs are ready.
      folders = {
        "Obsidian" = {
          id    = "obsidian";
          label = "Obsidian Vault";
          path  = "/home/linuxury/Obsidian";
          devices = [
            "Ryzen5900x"
            "Media-Server"
            "MinisForum"
            "Radxa-X4"
            "Pixel-Pro-8"
            # Add these when device IDs are ready:
            # "ThinkPad"
            # "Alex-Desktop"
            # "Alex-Laptop"
            # "Asus-A15"
            # "Ryzen5800x"
          ];
          fsWatcherEnabled = true;
          fsWatcherDelayS  = 10;
          rescanIntervalS  = 60;
          ignorePerms      = false;
        };
      };

      # ── Global options ─────────────────────────────────────────────────
      options = {
        localAnnounceEnabled = true;
        relaysEnabled        = false;  # Tailscale only, no public relays
        urAccepted           = -1;     # Decline usage reporting
      };
    };
  };

  # ── Firewall ──────────────────────────────────────────────────────────
  # Syncthing sync port (TCP + UDP) and local discovery (UDP)
  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 21027 ];
  };
}
