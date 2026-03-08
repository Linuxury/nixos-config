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
#   - base/common.nix
#   - samba.nix
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    ../../modules/base/common.nix
    ../../modules/base/linuxury-ssh.nix
    ../../modules/base/auto-update.nix
    ../../modules/base/server-shell.nix
    ../../modules/hardware/drivers.nix
    ../../modules/services/samba.nix
  ];

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "MinisForum";

  # =========================================================================
  # GPU driver selection
  # Intel Iris Xe integrated graphics
  # =========================================================================
  hardware.gpu = "intel";

  # =========================================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on server
  # =========================================================================
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

  # =========================================================================
  # Swap
  # =========================================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];

  # =========================================================================
  # Kernel — latest stable
  # Servers benefit from stability over bleeding edge
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # =========================================================================
  # Server optimizations
  #
  # Servers have different performance priorities than desktops.
  # These tweaks favor throughput and stability over interactivity.
  # =========================================================================
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

  # =========================================================================
  # Disable audio — servers don't need it
  # Overrides the PipeWire setup in common.nix
  # =========================================================================
  services.pipewire.enable = lib.mkForce false;

  # =========================================================================
  # Disable suspend/sleep — servers must stay on
  #
  # A server that suspends is useless. These settings ensure the machine
  # never sleeps regardless of inactivity.
  # =========================================================================
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

  # =========================================================================
  # Server packages
  #
  # Minimal set — only what you need to manage and monitor the server.
  # Services get their own packages when we configure them.
  # =========================================================================
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

  # =========================================================================
  # Game server directories
  #
  # Crafty owns everything under crafty/ — Docker mounts these as volumes.
  # Hytale runs directly under hytale/Server/ (downloaded via hytale-downloader).
  # =========================================================================
  systemd.tmpfiles.rules = [
    "d /data                                  0755 root     users -"
    "d /data/gameservers                      0775 linuxury users -"
    "d /data/gameservers/crafty               0775 linuxury users -"
    "d /data/gameservers/crafty/servers       0775 linuxury users -"
    "d /data/gameservers/crafty/backups       0775 linuxury users -"
    "d /data/gameservers/crafty/config        0775 linuxury users -"
    "d /data/gameservers/crafty/logs          0775 linuxury users -"
    "d /data/gameservers/crafty/import        0775 linuxury users -"
    "d /data/gameservers/hytale               0775 linuxury users -"
    "d /data/gameservers/hytale/Server        0775 linuxury users -"
  ];

  # =========================================================================
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
  #   19132/udp   — Minecraft Bedrock default (if you add a Bedrock server)
  #
  # To add more Minecraft ports (e.g. a second server on 25566):
  #   Add "25566:25566" to ports below and 25566 to allowedTCPPorts.
  # =========================================================================
  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.crafty = {
      image     = "registry.gitlab.com/crafty-controller/crafty-4:latest";
      autoStart = true;
      ports = [
        "8443:8443"       # Web UI
        "25565:25565"     # Minecraft Java (default server)
        "19132:19132/udp" # Minecraft Bedrock (optional)
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

  # =========================================================================
  # Hytale server — official binary, direct systemd service
  #
  # Uses Java 25 + QUIC/UDP on port 5520.
  # Server files live in /data/gameservers/hytale/Server/
  #
  # FIRST-TIME SETUP (run once as linuxury on MinisForum):
  #   cd /data/gameservers/hytale
  #   wget https://downloader.hytale.com/hytale-downloader.zip
  #   unzip hytale-downloader.zip
  #   chmod +x hytale-downloader-linux-amd64
  #   ./hytale-downloader-linux-amd64 -download-path server.zip
  #   unzip server.zip -d .
  #   mv Assets.zip Server/
  #
  #   # Run manually once to authenticate:
  #   cd Server
  #   java -jar HytaleServer.jar --assets Assets.zip --bind 0.0.0.0:5520
  #   # In the Hytale console:
  #   /auth login device       ← visit https://accounts.hytale.com/device + enter code
  #   /auth persistence Encrypted  ← persists credentials across reboots
  #   # Then Ctrl+C and start via systemd:
  #   sudo systemctl start hytale-server
  #
  # Service is gated on HytaleServer.jar existing — safe to rebuild before setup.
  # =========================================================================
  systemd.services.hytale-server = {
    description = "Hytale Game Server";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    wantedBy    = [ "multi-user.target" ];

    serviceConfig = {
      Type                    = "simple";
      User                    = "linuxury";
      WorkingDirectory        = "/data/gameservers/hytale/Server";
      ExecStart               = "${pkgs.jdk25_headless}/bin/java -jar HytaleServer.jar --assets Assets.zip --bind 0.0.0.0:5520";
      Restart                 = "on-failure";
      RestartSec              = "10s";
      # Only start if server files are present — prevents failure before first-time setup
      ConditionPathExists     = "/data/gameservers/hytale/Server/HytaleServer.jar";
    };
  };

  # =========================================================================
  # Samba — GameServers share for managing server files
  #
  # Access: \\MinisForum\GameServers
  # Mount on client with: sudo mount /mnt/MinisForum
  # (Add CIFS mount to each client host's fileSystems config)
  # =========================================================================
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
  networking.firewall.allowedUDPPorts = [ 137 138 19132 5520 ]; # 5520/udp — Hytale uses QUIC (UDP only)

  # =========================================================================
  # Tailscale — remote management
  # After first boot: sudo tailscale up
  # =========================================================================
  # First-boot checklist:
  #   1. sudo tailscale up
  #   2. sudo smbpasswd -a linuxury && sudo smbpasswd -a babylinux
  #   3. git clone git@github.com:Linuxury/nixos-config.git ~/nixos-config
  #   4. sudo chown -R linuxury:users ~/nixos-config   ← required if cloned as root
  # =========================================================================
  services.tailscale.enable = true;
  services.tailscale.extraUpFlags = [ "--advertise-tags=tag:ssh" ];

  # =========================================================================
  # Users
  # =========================================================================
  users.users = {
    linuxury = {
      isNormalUser = true;
      extraGroups  = [ "wheel" "networkmanager" "docker" ];
      shell        = pkgs.fish;
    };

    babylinux = {
      isNormalUser  = true;
      # No wheel — wife doesn't need server admin access
      extraGroups   = [ "networkmanager" ];
      shell         = pkgs.fish;
    };

    alex = {
      isNormalUser  = true;
      # No wheel — kid definitely doesn't need server access
      extraGroups   = [];
      shell         = pkgs.fish;
    };
  };

  programs.fish.enable = true;
}
