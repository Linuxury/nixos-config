# ===========================================================================
# modules/services/syncthing/default.nix — Syncthing file sync (all hosts)
#
# Imported by: all 9 hosts + phone
#
# Fully declarative Syncthing config — devices and folders hardcoded.
# No web UI setup needed after rebuild. Syncthing auto-pairs and syncs.
#
# Shared folders:
#   ~/Jarvis    — vault: session logs, research, projects, work, stack (ZenNotes)
#                 Per-client ZenNotes metadata excluded via ~/Jarvis/.stignore:
#                   .zennotes/
#   ~/.agents   — AI config: AGENTS.md, CLAUDE.md, Claude/OpenCode settings,
#                 MCP config, and mcp-servers/ source code.
#                 Runtime artifacts excluded via ~/.agents/.stignore:
#                   memory/, backups/, .venv, __pycache__, *.egg-info
# Device IDs generated fresh 2026-03-25 — no legacy config carried over.
# Phone (Pixel Pro 8) ID obtained from Syncthing-Fork app.
# ===========================================================================

{ lib, ... }:

{
  # Upstream's syncthing-init unit uses `Requisite=syncthing.service`, which
  # only checks that syncthing.service is *already active* at job-queue time
  # instead of waiting for it — during a rebuild/restart race this fails with
  # "Dependency failed", then systemd retries and it succeeds a moment later.
  # Swap Requisite for Requires so it waits instead of racing.
  systemd.services.syncthing-init.requisite = lib.mkForce [ ];
  systemd.services.syncthing-init.requires  = [ "syncthing.service" ];

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
          id = "INWQLVH-KBFFJLJ-YAPK7JQ-BLUEJNL-GMHVIMO-YX3G5JZ-PO2FMHS-MROBVAU";
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

        "Ryzen5800x" = {
          id = "KMIXV62-XWKZX73-I4D5TVY-QD4NQ5D-S4B4LSO-TGVU7V5-267HUAB-YDEGXQG";
          addresses = [ "tcp://100.114.95.99:22000" ];
        };

        # babylinux and alex machines have their own Syncthing instances
        # (syncthing-babylinux.nix, syncthing-alex.nix) but share the same
        # "jarvis" folder ID so they participate in the single sync group.

        "Pixel-Pro-8" = {
          id = "7PCGWBQ-DK3DAYL-A7ANW7E-TDWSUGW-IEVJHXH-34SAGCG-JEQ6ZH5-YRZL7A7";
          addresses = [ "tcp://100.102.143.76:22000" ];
        };
      };

      # ── Folders ────────────────────────────────────────────────────────
      # Single shared folder — the Obsidian vault. Devices with valid IDs
      # are listed here. FILL-IN devices are added when their IDs are ready.
      folders = {
        "Jarvis" = {
          id    = "jarvis";
          label = "Jarvis Vault";
          path  = "/home/linuxury/Jarvis";
          devices = [
            "Ryzen5900x"
            "ThinkPad"
            "Media-Server"
            "MinisForum"
            "Radxa-X4"
            "Pixel-Pro-8"
            "Ryzen5800x"
          ];
          fsWatcherEnabled = true;
          fsWatcherDelayS  = 10;
          rescanIntervalS  = 60;
          ignorePerms      = false;
        };

        "ai-config" = {
          id    = "ai-config";
          label = "AI Config";
          path  = "/home/linuxury/.agents";
          devices = [
            "Ryzen5900x"
            "ThinkPad"
            "Media-Server"
            "MinisForum"
            "Radxa-X4"
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
