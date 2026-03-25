# ===========================================================================
# hosts/Media-Server/couchdb.nix — CouchDB 3 for Obsidian LiveSync
#
# Runs CouchDB 3.x in Podman with LiveSync-required configuration.
# An init container configures CORS, auth, and size limits via the REST API.
# ===========================================================================

{ config, pkgs, ... }:

let
  dataDir   = "/data/couchdb";
  configDir = "/data/couchdb-config";
in
{
  # --------------------------------------------------------------------------
  # Agenix secret — CouchDB admin password
  # --------------------------------------------------------------------------
  age.secrets.couchdb-admin-password = {
    file    = ../../secrets/couchdb-admin-password.age;
    owner   = "linuxury";
    group   = "users";
    mode    = "0440";
  };

  # --------------------------------------------------------------------------
  # Podman container — CouchDB
  # --------------------------------------------------------------------------
  virtualisation.oci-containers.containers.couchdb = {
    image   = "docker.io/library/couchdb:3.5";
    autoStart = true;

    environment = {
      COUCHDB_USER = "admin";
    };

    environmentFiles = [
      config.age.secrets.couchdb-admin-password.path
    ];

    volumes = [
      "${dataDir}:/opt/couchdb/data"
      "${configDir}:/opt/couchdb/etc/local.d"
    ];

    ports = [
      "127.0.0.1:5984:5984"
    ];

    extraOptions = [
      "--health-cmd=curl -f http://localhost:5984/_up || exit 1"
      "--health-interval=30s"
      "--health-timeout=5s"
      "--health-retries=3"
    ];
  };

  # --------------------------------------------------------------------------
  # Init service — configure CouchDB for LiveSync
  #
  # Runs after CouchDB is healthy. Sets single-node cluster + all required
  # LiveSync settings via the REST API.
  # --------------------------------------------------------------------------
  systemd.services.couchdb-init = {
    description = "Configure CouchDB for Obsidian LiveSync";
    after       = [ "podman-couchdb.service" ];
    wants       = [ "podman-couchdb.service" ];
    wantedBy    = [ "multi-user.target" ];

    path = [ pkgs.curl pkgs.jq pkgs.bash ];

    script = ''
      set -euo pipefail

      # Read password from agenix secret
      COUCHDB_PASS=$(grep COUCHDB_PASSWORD= ${config.age.secrets.couchdb-admin-password.path} | cut -d= -f2-)

      echo "Waiting for CouchDB to be ready..."
      until curl -sf -u admin:"$COUCHDB_PASS" http://localhost:5984/_up > /dev/null 2>&1; do
        sleep 2
      done
      echo "CouchDB is up."

      # Check if already initialized (idempotent)
      SETUP_STATUS=$(curl -sf -u admin:"$COUCHDB_PASS" http://localhost:5984/_cluster_setup 2>/dev/null || echo '{"state":""}')
      STATE=$(echo "$SETUP_STATUS" | ${pkgs.jq}/bin/jq -r '.state // empty')

      if [ "$STATE" = "cluster_finished" ] || [ "$STATE" = "single_node_enabled" ]; then
        echo "CouchDB already initialized (state: $STATE). Skipping setup."
      else
        echo "Setting up single-node cluster..."
        curl -s -X POST -u admin:"$COUCHDB_PASS" http://localhost:5984/_cluster_setup \
          -H 'Content-Type: application/json' \
          -d '{"action":"enable_single_node","username":"admin","password":"'"$COUCHDB_PASS"'","bind_address":"0.0.0.0","port":5984,"singlenode":true}'
        echo ""
        echo "Cluster setup complete."
      fi

      echo "Configuring LiveSync settings..."

      # CouchDB settings for Obsidian LiveSync
      declare -A SETTINGS=(
        ["chttpd/require_valid_user"]="true"
        ["chttpd_auth/require_valid_user"]="true"
        ["httpd/WWW-Authenticate"]="Basic realm=\"couchdb\""
        ["httpd/enable_cors"]="true"
        ["chttpd/enable_cors"]="true"
        ["chttpd/max_http_request_size"]="4294967296"
        ["couchdb/max_document_size"]="50000000"
        ["cors/credentials"]="true"
        ["cors/origins"]="app://obsidian.md,capacitor://localhost,http://localhost"
      )

      for key in "''${!SETTINGS[@]}"; do
        IFS='/' read -r section param <<< "$key"
        value="''${SETTINGS[$key]}"
        echo "  Setting $section/$param = $value"
        curl -s -X PUT -u admin:"$COUCHDB_PASS" http://localhost:5984/_node/_local/_config/$section/$param \
          -H 'Content-Type: application/json' \
          -d "\"$value\"" > /dev/null
      done

      echo "CouchDB LiveSync configuration complete."
    '';

    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      User            = "linuxury";
    };
  };
}
