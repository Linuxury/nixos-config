# ===========================================================================
# modules/services/zennotes/default.nix — ZenNotes self-hosted server
#
# Keyboard-first Markdown notes with Vim motions, live math/diagrams,
# and an MCP server for AI assistant integration.
#
# Vault: /home/linuxury/Jarvis (plain .md files, synced by Syncthing, owned by linuxury)
# Data:  /data/config/zennotes    (server config on mergerfs)
# Port:  7879 (host) → 7878 (container) — 7878 is taken by Radarr
#
# Web UI / desktop: http://Media-Server:7879
#                   http://media-server.tail1023a0.ts.net:7879
#
# Auth token: secrets/zennotes-auth-token.age
#   File format: ZENNOTES_AUTH_TOKEN=<token>
#
# First boot:
#   1. nixos-rebuild switch on Media-Server
#   2. Log in at http://Media-Server:7879 with the token from the secret
#   3. Desktop app: Settings → Connect to Remote Vault → http://Media-Server:7879
# ===========================================================================

{ config, lib, ... }:

{
  # ===========================================================================
  # Podman backend
  # ===========================================================================
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # ===========================================================================
  # Agenix secret — auth token (env-file format: ZENNOTES_AUTH_TOKEN=<token>)
  # ===========================================================================
  age.secrets.zennotes-auth-token = {
    file = ../../../secrets/zennotes-auth-token.age;
    mode = "0400";
  };

  # ===========================================================================
  # Setup service — creates vault and data dirs before the container starts
  # ===========================================================================
  systemd.services.zennotes-setup = {
    description = "Set up ZenNotes vault and data directories";
    wantedBy    = [ "multi-user.target" ];
    before      = [ "podman-zennotes.service" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Vault dir is owned by linuxury — Syncthing also writes here.
      # Container runs as UID 1000 (linuxury) to avoid ownership conflicts.
      mkdir -p /home/linuxury/Jarvis
      chown linuxury:users /home/linuxury/Jarvis
      chmod 0755 /home/linuxury/Jarvis
      mkdir -p /data/config/zennotes
      chown linuxury:users /data/config/zennotes
    '';
  };

  systemd.services."podman-zennotes" = {
    after    = [ "zennotes-setup.service" "agenix.service" ];
    requires = [ "zennotes-setup.service" ];
    wants    = [ "agenix.service" ];
  };

  # ===========================================================================
  # Container
  # ===========================================================================
  virtualisation.oci-containers.containers = {
    zennotes = {
      image            = "docker.io/adibhanna/zennotes:latest";
      ports            = [ "7879:7878" ];
      volumes          = [
        "/home/linuxury/Jarvis:/workspace:z"
        "/data/config/zennotes:/data:z"
      ];
      environmentFiles = [ config.age.secrets.zennotes-auth-token.path ];
      # Run as linuxury (UID 1000) so Syncthing can also write to ~/Jarvis/
      extraOptions     = [ "--user=1000:1000" ];
    };
  };

  # ===========================================================================
  # Firewall — 7879 is the host-side port for ZenNotes
  # ===========================================================================
  networking.firewall.allowedTCPPorts = [ 7879 ];
}
