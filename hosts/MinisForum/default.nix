# ===========================================================================
# hosts/MinisForum/default.nix — MinisForum UN1250
#
# Owner: managed by linuxury
# Hardware: Intel Core i5-1250P, Intel Iris Xe integrated graphics
# Type: Headless server — no DE, no display manager
# Role: Game server host
#   - Crafty Controller (Docker, web UI on port 8443)
#       Manages Minecraft servers (Java) and the Hytale server (QUIC/UDP 5520)
#       Access: https://MinisForum:8443  (or via Tailscale)
#       First login: admin / crafty  (change immediately)
#
# Storage layout:
#   /data/gameservers/crafty/servers/  — Crafty-managed server files
#   /data/gameservers/crafty/backups/  — Crafty backups
#   /data/gameservers/crafty/config/   — Crafty config + SSL cert
#   /data/gameservers/crafty/logs/     — Crafty logs
#   /data/gameservers/crafty/import/   — Drop server ZIPs here to import
#
# Samba share: \\MinisForum\GameServers → /data/gameservers
#   Access via /mnt/MinisForum on client machines (add CIFS mount per host)
#
# Enabled modules:
#   - Intel drivers
#   - system/core/default.nix
#   - services/samba/default.nix
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  imports = [
    # Disks, swap, LUKS and boot loader (written by the installer)
    ./disk.nix

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

    # ==============================================================
    # Development — AI Tools
    #   ai-tools  — base: nix-ld, uv, ffmpeg (import alongside tools below)
    #   claude    — Claude Code CLI
    #   opencode  — OpenCode CLI
    #   local-llm — Ollama + GPU acceleration
    # ==============================================================
    ../../modules/development/ai-tools/default.nix
    ../../modules/development/ai-tools/claude/default.nix
    #../../modules/development/ai-tools/opencode/default.nix
    #../../modules/development/ai-tools/local-llm/default.nix

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

  # Staggered off the 03:00 default so the fleet does not hit GitHub (60
  # calls/hour, shared home IP) and cache.nixos.org on the same second.
  services.nixos-auto-update.schedule = "*-*-* 02:00";

  # ==============================================================
  # GPU driver selection
  # Intel Iris Xe integrated graphics
  # ==============================================================
  hardware.gpu = "intel";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # ==============================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on server
  # ==============================================================

  # ==============================================================
  # Kernel — latest stable
  # Servers benefit from stability over bleeding edge
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;           # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

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
      "uid=${toString config.users.users.linuxury.uid}"
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
  ];

  # ==============================================================
  # Crafty Controller — web-based Minecraft server manager
  #
  # Runs in Docker. Manages the Minecraft servers and the Hytale server.
  # Crafty doesn't auto-publish Hytale's UDP port, so it's mapped by hand
  # below (and opened in the firewall).
  #
  # Web UI:  https://MinisForum:8443  (self-signed cert, click through)
  #          or https://<tailscale-ip>:8443
  # Default credentials: admin / crafty  ← change on first login
  #
  # Ports mapped to host:
  #   8443        — Crafty web UI (HTTPS)
  #   25565       — Minecraft Java: Dark Fortress [26.2]
  #   25566       — Minecraft Java: Homestead [1.3.7]
  #   24454/udp   — Simple Voice Chat (Homestead ships voicechat)
  #   5520/udp    — Hytale: Dark Fortress (QUIC)
  #
  # To add more Minecraft ports (e.g. a third server on 25567):
  #   Add "25567:25567" to ports below and 25567 to allowedTCPPorts.
  # ==============================================================
  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.crafty = {
      # Floating tag + pull="always": every container start checks the registry
      # digest and only downloads changed layers. ("newer" is podman-only.)
      # The weekly restart below triggers that.
      image     = "registry.gitlab.com/crafty-controller/crafty-4:latest";
      pull      = "always";
      autoStart = true;
      ports = [
        "8443:8443"         # Web UI
        "25565:25565"       # Minecraft Java — Dark Fortress [26.2]
        "25566:25566"       # Minecraft Java — Homestead [1.3.7]
        "24454:24454/udp"   # Simple Voice Chat — Homestead
        "5520:5520/udp"     # Hytale — Dark Fortress
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

  # Weekly restart so the container re-checks :latest (see pull above).
  # Monday 04:00 — least likely time for anyone to be on a server.
  systemd.services.crafty-update = {
    description = "Restart Crafty to pull a newer :latest image";
    serviceConfig.Type = "oneshot";
    script = "systemctl restart docker-crafty.service";
  };
  systemd.timers.crafty-update = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "Mon 04:00";
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

  networking.firewall.allowedTCPPorts = [ 445 139 8443 25565 25566 ];
  networking.firewall.allowedUDPPorts = [ 137 138 24454 5520 ]; # 24454 — Simple Voice Chat; 5520 — Hytale (QUIC/UDP only)

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
  services.tailscale.extraUpFlags = [ "--advertise-tags=tag:ssh" ];

  # ==============================================================
  # Users
  # ==============================================================
  users.users = {
    linuxury = {
      isNormalUser = true;
      extraGroups  = [ "wheel" "networkmanager" "docker" ];
      shell        = pkgs.zsh;
    };

    babylinux = {
      isNormalUser  = true;
      # No wheel — wife doesn't need server admin access
      extraGroups   = [ "networkmanager" "docker" ];
      shell         = pkgs.zsh;
    };

    alex = {
      isNormalUser  = true;
      # No wheel — kid definitely doesn't need server access
      extraGroups   = [];
      shell         = pkgs.zsh;
    };

    # ------------------------------------------------------------
    # nixbuilder — remote build account for the fleet
    #
    # Weak hosts (Radxa-X4, Media-Server, ThinkPad) offload their
    # derivations here instead of grinding at 1-2 jobs. They connect as
    # THIS user, not root — core/default.nix sets PermitRootLogin = "no"
    # fleet-wide, and Nix does not need root on a builder anyway.
    #
    # The private half lives in secrets/nix-builder-key.age and is
    # deployed only to the three clients. Public keys are safe in git.
    #
    # ⚠ This account is a trusted-user below, which means it can insert
    # arbitrary paths into this host's Nix store — root-equivalent HERE.
    # Only add clients you control; see secrets/secrets.nix.
    # ------------------------------------------------------------
    nixbuilder = {
      isNormalUser = true;
      description  = "Remote Nix build account";
      shell        = pkgs.bash;   # needs a real shell for nix-store --serve
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCxGxusdbuSGqgAD8qTkTJ3sZpvrFvVJyx8uI4QP3cU fleet-builder"
      ];
    };
  };

  # ==============================================================
  # Remote builder — builder side
  #
  # nixbuilder must be trusted to import the store paths it builds for
  # clients. This list CONCATENATES with core/default.nix's
  # [ "root" "@wheel" ] rather than replacing it.
  #
  # Dispatch is capped client-side (maxJobs = 2 in
  # modules/system/remote-builder.nix), matching this host's own 2 x 16, so
  # Crafty keeps headroom. The idle CPU/IO scheduling from f002d7ec
  # means remote builds yield to the game server.
  # ==============================================================
  nix.settings.trusted-users = [ "nixbuilder" ];
}
