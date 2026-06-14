# ===========================================================================
# modules/development/ai-tools/odysseus/default.nix — Odysseus AI workspace
#
# Self-hosted AI workspace with chat, autonomous agents, deep research,
# email assistant, persistent memory, MCP server support, and a 270+ model
# cookbook.
#
# Deployment: 4 Podman containers on a private `odysseus` network.
#
#   odysseus          — FastAPI backend + JS frontend   host port 7000
#   odysseus-chromadb — vector store (persistent memory) internal only
#   odysseus-searxng  — self-hosted search engine        internal only
#   odysseus-ntfy     — push notifications               host port 8091
#
# SearXNG runs internal-only (no host port) — avoids conflict with
# FreshRSS on port 8080. Containers discover each other by service name
# (chromadb, searxng, ntfy) within the odysseus Podman network.
#
# First boot:
#   1. nixos-rebuild switch on Media-Server
#   2. Open http://Media-Server:7000 and complete the setup wizard
#   3. In Odysseus settings, configure ntfy: http://Media-Server:8091
#
# Data is persisted to /data/config/odysseus/ on the mergerfs volume.
# SearXNG secret is generated once at first boot and stored there.
# ===========================================================================

{ lib, pkgs, ... }:

{
  # ===========================================================================
  # Podman backend
  # ===========================================================================
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # ===========================================================================
  # Setup service — runs once before containers start
  #   - Creates the odysseus Podman network (idempotent)
  #   - Creates persistent data directories under /data/config/odysseus/
  #   - Generates SearXNG settings.yml with a random secret on first boot
  # ===========================================================================
  systemd.services.odysseus-setup = {
    description = "Set up Odysseus network, directories, and config";
    wantedBy    = [ "multi-user.target" ];
    before = [
      "podman-odysseus.service"
      "podman-odysseus-chromadb.service"
      "podman-odysseus-searxng.service"
      "podman-odysseus-ntfy.service"
    ];
    path = [ pkgs.podman pkgs.openssl ];
    serviceConfig = {
      Type             = "oneshot";
      RemainAfterExit  = true;
    };
    script = ''
      # Podman network (idempotent)
      podman network exists odysseus 2>/dev/null || podman network create odysseus

      # Persistent data directories
      mkdir -p /data/config/odysseus/{data,logs,ssh,huggingface,local,chromadb,searxng,ntfy-cache}

      # SearXNG settings.yml — generated once with a random secret
      if [ ! -f /data/config/odysseus/searxng/settings.yml ]; then
        SECRET=$(openssl rand -base64 48 | tr -d '=\n')
        cat > /data/config/odysseus/searxng/settings.yml <<EOF
use_default_settings: true

server:
  secret_key: "$SECRET"

search:
  formats:
    - html
    - json
EOF
      fi
    '';
  };

  # All containers wait for the setup service before starting
  systemd.services."podman-odysseus"          = { after = [ "odysseus-setup.service" ]; requires = [ "odysseus-setup.service" ]; };
  systemd.services."podman-odysseus-chromadb" = { after = [ "odysseus-setup.service" ]; requires = [ "odysseus-setup.service" ]; };
  systemd.services."podman-odysseus-searxng"  = { after = [ "odysseus-setup.service" ]; requires = [ "odysseus-setup.service" ]; };
  systemd.services."podman-odysseus-ntfy"     = { after = [ "odysseus-setup.service" ]; requires = [ "odysseus-setup.service" ]; };

  # ===========================================================================
  # Containers
  # ===========================================================================
  virtualisation.oci-containers.containers = {

    # -------------------------------------------------------------------------
    # Odysseus — main app
    # Web UI: http://Media-Server:7000
    # Waits for chromadb and searxng to be healthy before starting.
    # host.docker.internal → host IP, lets odysseus reach Ollama on the host.
    # -------------------------------------------------------------------------
    odysseus = {
      image      = "ghcr.io/pewdiepie-archdaemon/odysseus:1.0.0";
      dependsOn  = [ "odysseus-chromadb" "odysseus-searxng" "odysseus-ntfy" ];
      ports      = [ "7000:7000" ];
      volumes    = [
        "/data/config/odysseus/data:/app/data:z"
        "/data/config/odysseus/logs:/app/logs:z"
        "/data/config/odysseus/ssh:/app/.ssh:z"
        "/data/config/odysseus/huggingface:/app/.cache/huggingface:z"
        "/data/config/odysseus/local:/app/.local:z"
      ];
      environment = {
        CHROMADB_HOST    = "chromadb";
        CHROMADB_PORT    = "8000";
        SEARXNG_INSTANCE = "http://searxng:8080";
        AUTH_ENABLED     = "true";
        LOCALHOST_BYPASS = "false";
        SECURE_COOKIES   = "false";
        ALLOWED_ORIGINS  = "http://Media-Server:7000,http://localhost:7000";
        PUID             = "1000";
        PGID             = "1000";
      };
      extraOptions = [
        "--network=odysseus"
        "--network-alias=odysseus"
        "--add-host=host.docker.internal:host-gateway"
      ];
    };

    # -------------------------------------------------------------------------
    # ChromaDB — vector store for persistent memory
    # Internal only — reachable as `chromadb:8000` from within the network.
    # -------------------------------------------------------------------------
    odysseus-chromadb = {
      image   = "docker.io/chromadb/chroma:latest";
      volumes = [ "/data/config/odysseus/chromadb:/chroma/chroma" ];
      environment = {
        ANONYMIZED_TELEMETRY = "FALSE";
      };
      extraOptions = [
        "--network=odysseus"
        "--network-alias=chromadb"
      ];
    };

    # -------------------------------------------------------------------------
    # SearXNG — self-hosted search engine
    # Internal only — no host port mapping, so no conflict with FreshRSS:8080.
    # Reachable as `searxng:8080` from odysseus within the network.
    # settings.yml is generated by odysseus-setup on first boot.
    # -------------------------------------------------------------------------
    odysseus-searxng = {
      image   = "docker.io/searxng/searxng:2026.5.31-7159b8aed";
      volumes = [ "/data/config/odysseus/searxng:/etc/searxng:z" ];
      environment = {
        SEARXNG_BASE_URL = "http://localhost:8080/";
      };
      extraOptions = [
        "--network=odysseus"
        "--network-alias=searxng"
        "--cap-drop=ALL"
        "--cap-add=CHOWN"
        "--cap-add=SETGID"
        "--cap-add=SETUID"
        "--cap-add=DAC_OVERRIDE"
      ];
    };

    # -------------------------------------------------------------------------
    # ntfy — push notifications for the Odysseus workspace
    # Separate from the system ntfy on port 2586 (NixOS update alerts).
    # Configure in Odysseus settings: http://Media-Server:8091
    # ntfy app / browser: http://Media-Server:8091
    # -------------------------------------------------------------------------
    odysseus-ntfy = {
      image  = "docker.io/binwiederhier/ntfy";
      cmd    = [ "serve" ];
      ports  = [ "8091:80" ];
      volumes = [ "/data/config/odysseus/ntfy-cache:/var/cache/ntfy" ];
      environment = {
        NTFY_BASE_URL = "http://Media-Server:8091";
      };
      extraOptions = [
        "--network=odysseus"
        "--network-alias=ntfy"
      ];
    };

  };

  # ===========================================================================
  # Firewall
  #   7000 — Odysseus web UI
  #   8091 — Odysseus ntfy (push notifications)
  # ===========================================================================
  networking.firewall.allowedTCPPorts = [ 7000 8091 ];
}
