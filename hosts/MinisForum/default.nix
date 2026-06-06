# ===========================================================================
# hosts/MinisForum/default.nix — MinisForum UN1250
#
# Owner: managed by linuxury
# Hardware: Intel Core i5-1250P, Intel Iris Xe integrated graphics
# Type: Headless server — no DE, no display manager
# Role: Game server host
#   - Crafty Controller (Docker, web UI on port 8443)
#       Manages Minecraft servers (Java + Bedrock) only
#       Access: https://MinisForum:8443  (or via Tailscale)
#       First login: admin / crafty  (change immediately)
#   - Hytale server (systemd service, QUIC/UDP port 5520)
#       Official binary via hytale-downloader — see FIRST-TIME SETUP comment
#       Files: /data/gameservers/hytale/Server/
#
# Storage layout:
#   /data/gameservers/crafty/servers/  — Crafty-managed server files
#   /data/gameservers/crafty/backups/  — Crafty backups
#   /data/gameservers/crafty/config/   — Crafty config + SSL cert
#   /data/gameservers/crafty/logs/     — Crafty logs
#   /data/gameservers/crafty/import/   — Drop server ZIPs here to import
#   /data/gameservers/hytale/          — Hytale server files
#
# Samba share: \\MinisForum\GameServers → /data/gameservers
#   Access via /mnt/MinisForum on client machines (add CIFS mount per host)
#
# Enabled modules:
#   - Intel drivers
#   - system/core/default.nix
#   - services/samba/default.nix
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    # ==============================================================
    # System
    #   core         — locale, fonts, nix daemon, base CLI, boot defaults
    #   server-shell — headless zsh, aliases, zoxide/fzf/direnv
    # ==============================================================
    ../../modules/system/core/default.nix
    ../../modules/system/server-shell/default.nix

    # ==============================================================
    # Hardware
    #   drivers — Intel Iris Xe iGPU + basic support
    # ==============================================================
    ../../modules/hardware/drivers/default.nix
    #../../modules/hardware/openrgb/default.nix

    # ==============================================================
    # Development — AI Tools
    #   ai-tools  — base: nix-ld, uv, ffmpeg (import alongside tools below)
    #   claude    — Claude Code CLI
    #   opencode  — OpenCode CLI
    #   local-llm — Ollama + GPU acceleration
    #   odysseus  — self-hosted AI workspace
    # ==============================================================
    ../../modules/development/ai-tools/default.nix
    ../../modules/development/ai-tools/claude/default.nix
    #../../modules/development/ai-tools/opencode/default.nix
    #../../modules/development/ai-tools/local-llm/default.nix
    #../../modules/development/ai-tools/odysseus/default.nix

    # ==============================================================
    # Development — Editors (headless — no GUI editors)
    # ==============================================================
    #../../modules/development/editors/neovim/default.nix
    #../../modules/development/editors/vscodium/default.nix
    #../../modules/development/editors/zed/default.nix

    # ==============================================================
    # Development — Languages
    #   python — python3, poetry, ruff, httpie
    #   rust   — rustup toolchain, cargo tools, just
    # ==============================================================
    #../../modules/development/languages/python/default.nix
    #../../modules/development/languages/rust/default.nix

    # ==============================================================
    # Services
    #   samba       — GameServers share at /data/gameservers
    #   syncthing   — vault + nixos-config sync (linuxury pair)
    #   auto-update — weekly nixos-rebuild from GitHub
    # ==============================================================
    ../../modules/services/samba/default.nix
    ../../modules/services/syncthing/default.nix
    ../../modules/services/auto-update/default.nix
    #../../modules/services/ntfy/default.nix
    #../../modules/services/vpn-qbittorrent/default.nix
    #../../modules/services/snapper/default.nix
    #../../modules/services/syncthing-babylinux/default.nix

    # ==============================================================
    # Users
    #   ssh — authorized keys for this host
    # ==============================================================
    ../../modules/users/linuxury/ssh/default.nix
  ];

  # ==============================================================
  # Host identity
  # ==============================================================
  networking.hostName = "MinisForum";

  # ==============================================================
  # GPU driver selection
  # Intel Iris Xe integrated graphics
  # ==============================================================
  hardware.gpu = "intel";

  # ==============================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on server
  # ==============================================================
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd:1" "noatime" ];
    };

    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd:1" "noatime" ];
    };

    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@nix" "compress=zstd:1" "noatime" ];
    };

    "/var/log" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@log" "compress=zstd:1" "noatime" ];
    };

    "/var/cache" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@cache" "compress=zstd:1" "noatime" ];
    };

    "/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@snapshots" "compress=zstd:1" "noatime" ];
    };

    "/swap" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@swap" "noatime" ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };

  # ==============================================================
  # Swap
  # ==============================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];

  # ==============================================================
  # Kernel — latest stable
  # Servers benefit from stability over bleeding edge
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ==============================================================
  # Server optimizations
  #
  # Servers have different performance priorities than desktops.
  # These tweaks favor throughput and stability over interactivity.
  # ==============================================================
  boot.kernel.sysctl = {
    # Network performance
    "net.core.rmem_max"          = 134217728;  # Increase receive buffer
    "net.core.wmem_max"          = 134217728;  # Increase send buffer
    "net.ipv4.tcp_rmem"          = "4096 87380 134217728";
    "net.ipv4.tcp_wmem"          = "4096 65536 134217728";
    "net.core.netdev_max_backlog" = 5000;       # Handle bursts of traffic

    # File system
    "fs.inotify.max_user_watches" = 524288;    # Needed by some services
                                               # that watch many files
  };

  # ==============================================================
  # Disable audio — servers don't need it
  # Overrides the PipeWire setup in common.nix
  # ==============================================================
  services.pipewire.enable = lib.mkForce false;

  # ==============================================================
  # Disable suspend/sleep — servers must stay on
  #
  # A server that suspends is useless. These settings ensure the machine
  # never sleeps regardless of inactivity.
  # ==============================================================
  systemd.targets.sleep.enable      = false;
  systemd.targets.suspend.enable    = false;
  systemd.targets.hibernate.enable  = false;
  systemd.targets.hybrid-sleep.enable = false;

  services.logind.settings.Login = {
    HandleSuspendKey             = "ignore";
    HandleHibernateKey           = "ignore";
    HandleLidSwitch              = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    IdleAction                   = "ignore";
  };

  # ==============================================================
  # Server packages
  #
  # Minimal set — only what you need to manage and monitor the server.
  # Services get their own packages when we configure them.
  # ==============================================================
  environment.systemPackages = with pkgs; [
    # Monitoring
    htop          # Already in common.nix but worth noting
    iotop         # Monitor disk I/O per process
    nethogs       # Monitor network usage per process
    ncdu          # Disk usage analyzer — find what's eating space
    smartmontools # Monitor hard drive health (S.M.A.R.T.)

    # File management
    rsync         # Fast file sync and backup tool
    rclone        # Cloud storage sync (useful for backups)
    cifs-utils    # Required for CIFS/Samba mounts

    # Utilities
    tmux          # Terminal multiplexer — keep sessions alive over SSH
                  # If your SSH connection drops, tmux keeps things running
    lsof          # List open files — useful for debugging
    strace        # Trace system calls — useful for debugging services

    # Hytale server runtime
    jdk25_headless # Required by HytaleServer.jar
    wget           # Download hytale-downloader
    unzip          # Extract server zip
  ];

  # ==============================================================
  # Agenix secrets
  # ==============================================================
  age.secrets.smb-credentials = {
    file = ../../secrets/smb-credentials.age;
    mode = "0400";
    owner = "root";
  };

  # ==============================================================
  # Media-Server Samba share — for Obsidian vault and shared files
  # Automounts on first access, disconnects after 60s idle.
  # ==============================================================
  fileSystems."/mnt/Media-Server" = {
    device = "//10.0.0.3/Media-Server";
    fsType = "cifs";
    options = [
      "credentials=/run/agenix/smb-credentials"
      "uid=1000"
      "gid=100"
      "nofail"
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=2s"
    ];
  };

  # ==============================================================
  # Game server directories
  #
  # Crafty owns everything under crafty/ — Docker mounts these as volumes.
  # Hytale runs directly under hytale/Server/ (downloaded via hytale-downloader).
  # ==============================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server                    0755 linuxury users -"
    "d /data                                  0755 root     users -"
    "d /data/gameservers                      0775 linuxury users -"
    "d /data/gameservers/crafty               0775 linuxury users -"
    "d /data/gameservers/crafty/servers       0775 linuxury users -"
    "d /data/gameservers/crafty/backups       0775 linuxury users -"
    "d /data/gameservers/crafty/config        0775 linuxury users -"
    "d /data/gameservers/crafty/logs          0775 linuxury users -"
    "d /data/gameservers/crafty/import        0775 linuxury users -"
    # Z = recursively fix ownership on existing files (crafty container runs as UID 1000)
    # GID 100 (users) so linuxury (also UID 1000) is owner + group access is consistent
    "Z /data/gameservers/crafty              -     1000  100   - -"
    "d /data/gameservers/hytale               0775 linuxury users -"
    "d /data/gameservers/hytale/Server        0775 linuxury users -"
  ];

  # ==============================================================
  # Crafty Controller — web-based Minecraft server manager
  #
  # Runs in Docker. Manages Minecraft servers only (Java + Bedrock).
  # Hytale is managed directly via systemd (see below).
  #
  # Web UI:  https://MinisForum:8443  (self-signed cert, click through)
  #          or https://<tailscale-ip>:8443
  # Default credentials: admin / crafty  ← change on first login
  #
  # Ports mapped to host:
  #   8443        — Crafty web UI (HTTPS)
  #   25565       — Minecraft Java default (add more in Crafty UI as needed)
  #
  # To add more Minecraft ports (e.g. a second server on 25566):
  #   Add "25566:25566" to ports below and 25566 to allowedTCPPorts.
  # ==============================================================
  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.crafty = {
      image     = "registry.gitlab.com/crafty-controller/crafty-4:latest";
      autoStart = true;
      ports = [
        "8443:8443"       # Web UI
        "25565:25565"     # Minecraft Java (default server)
      ];
      volumes = [
        "/data/gameservers/crafty/backups:/crafty/backups"
        "/data/gameservers/crafty/logs:/crafty/logs"
        "/data/gameservers/crafty/servers:/crafty/servers"
        "/data/gameservers/crafty/config:/crafty/app/config"
        "/data/gameservers/crafty/import:/crafty/import"
      ];
    };
  };

  # ==============================================================
  # Hytale server — official binary, direct systemd service
  #
  # Uses Java 25 + QUIC/UDP on port 5520.
  # Server files live in /data/gameservers/hytale/Server/
  # Current version: 0.5.2 (as of 2026-05-27)
  #
  # FIRST-TIME SETUP (run once as linuxury on MinisForum):
  #   cd /data/gameservers/hytale
  #   wget https://downloader.hytale.com/hytale-downloader.zip
  #   unzip hytale-downloader.zip
  #   chmod +x hytale-downloader-linux-amd64
  #   ./hytale-downloader-linux-amd64 -download-path server.zip
  #   # → first run triggers OAuth2 device flow: visit URL shown + enter code
  #   unzip server.zip -d .
  #   mv Assets.zip Server/
  #
  #   # Run manually once to authenticate the SERVER (separate from downloader auth):
  #   cd Server
  #   java -jar HytaleServer.jar --assets Assets.zip --bind 0.0.0.0:5520
  #   # In the Hytale console:
  #   /auth login device       ← visit https://accounts.hytale.com/device + enter code
  #   /auth persistence Encrypted  ← persists credentials across reboots
  #   # Then Ctrl+C and start via systemd:
  #   sudo systemctl start hytale-server
  #
  # Service is gated on both files existing — safe to rebuild before setup.
  #
  # START / STOP / LOGS:
  #   sudo systemctl start hytale-server
  #   sudo systemctl stop hytale-server
  #   sudo systemctl status hytale-server
  #   journalctl -u hytale-server -f        ← watch logs live
  #   (auto-starts on boot once files are present)
  #
  # UPDATE (preferred — from desktop/laptop):
  #   hytale-update        ← zsh function in linuxury's home.nix; handles everything
  #
  # UPDATE (manual — SSH to MinisForum):
  #   sudo systemctl stop hytale-server
  #   cd /data/gameservers/hytale
  #   wget -O hytale-downloader.zip https://downloader.hytale.com/hytale-downloader.zip
  #   unzip -o hytale-downloader.zip && chmod +x hytale-downloader-linux-amd64 && rm hytale-downloader.zip
  #   ./hytale-downloader-linux-amd64 -download-path server.zip
  #   unzip -o server.zip -d . && mv -f Assets.zip Server/ && rm -f server.zip
  #   rm -rf Server/update-staging 2>/dev/null || true
  #   sudo systemctl start hytale-server
  #   (auth credentials, server config, and mods survive updates)
  #
  # NOTE: The downloader is versioned — always re-download it before updating.
  # NOTE: Exit code 8 = auto-update staged internally (new in Update 2).
  #       The hytale-update function clears staging so manual updates win cleanly.
  #
  # OAUTH RE-AUTH (downloader credentials expire ~every 90 days):
  #   If hytale-update fails with "oauth2: invalid_grant":
  #   ssh -t MinisForum
  #   cd /data/gameservers/hytale
  #   rm .hytale-downloader-credentials.json   ← delete the stale token
  #   ./hytale-downloader-linux-amd64 -download-path server.zip
  #   → follow device auth flow → credentials auto-saved → continue update manually
  #   Note: server's auth.enc and downloader's .hytale-downloader-credentials.json
  #         are SEPARATE — one expiring does not affect the other.
  #
  # MOD MANAGEMENT:
  #   Mods live in Server/mods/. Incompatible mods (wrong server version) crash
  #   the server at startup with "Asset validation FAILED" or "Failed to start <mod>".
  #   Move broken mods to Server/mods/disabled/ until an update is available:
  #     mv Server/mods/SomeMod-1.0.0.jar Server/mods/disabled/
  #     sudo systemctl restart hytale-server
  #   To re-enable after an update: move back from disabled/ to mods/ and restart.
  #   Currently disabled (incompatible with 0.5.2, awaiting mod updates):
  #     - Miners-Helmet-1.0.3.zip      (item JSON format changed)
  #     - ReviveMe.jar + ReviveMe/     (plugin API changed)
  #     - HyCitizens-1.6.0.jar + data  (CitizenInteraction builder broken)
  # ==============================================================
  systemd.services.hytale-server = {
    description = "Hytale Game Server";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    wantedBy    = [ "multi-user.target" ];

    # Guard: only start if both server files are present.
    # ConditionPathExists must be in [Unit] (unitConfig), not [Service].
    # When either file is missing, systemd skips cleanly — no failure.
    # After first-time setup run: sudo systemctl start hytale-server
    unitConfig.ConditionPathExists = [
      "/data/gameservers/hytale/Server/HytaleServer.jar"
      "/data/gameservers/hytale/Server/Assets.zip"
    ];

    serviceConfig = {
      Type             = "simple";
      User             = "linuxury";
      WorkingDirectory = "/data/gameservers/hytale/Server";
      ExecStart        = "${pkgs.jdk25_headless}/bin/java -jar HytaleServer.jar --assets Assets.zip --bind 0.0.0.0:5520";
      Restart          = "on-failure";
      RestartSec       = "10s";
    };
  };

  # ==============================================================
  # Samba — GameServers share for managing server files
  #
  # Access: \\MinisForum\GameServers
  # Mount on client with: sudo mount /mnt/MinisForum
  # (Add CIFS mount to each client host's fileSystems config)
  # ==============================================================
  services.samba.settings = {
    "GameServers" = {
      path             = "/data/gameservers";
      comment          = "Game server files";
      browseable       = "yes";
      "read only"      = "no";
      "valid users"    = "linuxury babylinux";
      "create mask"    = "0664";
      "directory mask" = "0775";
    };
  };

  networking.firewall.allowedTCPPorts = [ 445 139 8443 25565 ];
  networking.firewall.allowedUDPPorts = [ 137 138 5520 ]; # 5520/udp — Hytale uses QUIC (UDP only)

  # ==============================================================
  # Sudo — NOPASSWD for Hytale service control
  #
  # Required by the `hytale-update` zsh function on linuxury's desktop/laptop.
  # That function runs over SSH without a TTY, so sudo can't prompt interactively.
  # Scoped tightly: only start/stop/restart for hytale-server, nothing else.
  # ==============================================================
  security.sudo.extraRules = [
    {
      users   = [ "linuxury" ];
      commands = [
        { command = "/run/current-system/sw/bin/systemctl start hytale-server";   options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/systemctl stop hytale-server";    options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/systemctl restart hytale-server"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  # ==============================================================
  # Tailscale — remote management
  # After first boot: sudo tailscale up
  # ==============================================================
  # First-boot checklist:
  #   1. sudo tailscale up
  #   2. sudo smbpasswd -a linuxury && sudo smbpasswd -a babylinux
  #   3. git clone git@github.com:Linuxury/nixos-config.git ~/nixos-config
  #   4. sudo chown -R linuxury:users ~/nixos-config   ← required if cloned as root
  # ==============================================================
  services.tailscale.enable = true;
  services.tailscale.extraUpFlags = [ "--advertise-tags=tag:ssh" ];

  # ==============================================================
  # Users
  # ==============================================================
  users.users = {
    linuxury = {
      isNormalUser = true;
      uid          = 1000;  # Pinned — primary admin; NixOS assigns UIDs alphabetically
                            # without pins (alex=1000, babylinux=1001, linuxury=1002)
      extraGroups  = [ "wheel" "networkmanager" "docker" ];
      shell        = pkgs.zsh;
    };

    babylinux = {
      isNormalUser  = true;
      uid           = 1001;  # Pinned — second user
      # No wheel — wife doesn't need server admin access
      extraGroups   = [ "networkmanager" "docker" ];
      shell         = pkgs.zsh;
    };

    alex = {
      isNormalUser  = true;
      uid           = 1002;  # Pinned — third user (kid account)
      # No wheel — kid definitely doesn't need server access
      extraGroups   = [];
      shell         = pkgs.zsh;
    };
  };
}
