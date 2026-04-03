# ===========================================================================
# modules/services/ntfy.nix — Self-hosted push notification server
#
# ntfy is a simple HTTP-based pub/sub notification service.
# All 9 hosts send update events here via curl; you subscribe on your
# phone and desktop to receive them in real time.
#
# Imported by: hosts/Media-Server/default.nix
#
# Phone setup:
#   1. Install the ntfy app (Android / iOS — free)
#   2. Change the server to http://<media-server-tailscale-ip>:2586
#   3. Subscribe to topic: nixos-updates
#
# Desktop setup (browser):
#   http://media-server:2586 → subscribe to nixos-updates
#
# Access from outside the LAN: use Tailscale (already on all hosts).
# Media-Server's Tailscale IP is stable — use it in the ntfy app.
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  services.ntfy-sh = {
    enable = true;
    settings = {
      # URL used in the web UI and for attachment links
      base-url     = "http://media-server:2586";
      # Listen on all interfaces so both LAN and Tailscale can reach it
      listen-http  = ":2586";
      # Cache messages so the phone gets missed notifications on reconnect
      cache-file     = "/var/lib/ntfy-sh/cache.db";
      cache-duration = "12h";
    };
  };

  # Open ntfy port on the firewall
  networking.firewall.allowedTCPPorts = [ 2586 ];
}
