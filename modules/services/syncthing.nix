# ===========================================================================
# modules/services/syncthing.nix — Syncthing file sync (linuxury)
#
# Imported by: ThinkPad, Ryzen5900x
#
# Syncs ~/Obsidian across both NixOS machines and the phone over Tailscale.
# Web UI available at http://localhost:8384 — use it for initial device pairing.
#
# Setup steps (first time on each machine):
#   1. After rebuild, open http://localhost:8384
#   2. Actions → Show ID — copy the device ID
#   3. On the other machine, Add Device → paste the ID
#   4. On phone (Syncthing-Fork), do the same
#   5. Share the ~/Obsidian folder with all paired devices
#
# Syncthing uses Tailscale IPs automatically when devices are on the same
# Tailscale network, no extra config needed.
# ===========================================================================

{ ... }:

{
  services.syncthing = {
    enable        = true;
    user          = "linuxury";
    dataDir       = "/home/linuxury";
    configDir     = "/home/linuxury/.config/syncthing";

    # Don't wipe manually configured devices/folders on rebuild
    overrideDevices = false;
    overrideFolders = false;

    settings.gui = {
      address = "127.0.0.1:8384";
    };
  };

  # Syncthing data sync port (TCP + UDP) and local discovery (UDP)
  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 21027 ];
  };
}
