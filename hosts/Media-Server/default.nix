# ===========================================================================
# hosts/Media-Server/default.nix — Media Server
#
# Owner: managed by linuxury
# Hardware: AMD Ryzen 5 3600x, AMD Radeon RX 480
# Type: Headless server — no DE, no display manager
# Role: Media server — Plex, Arr stack, Immich, file serving
#
# Storage:
#   - NVMe 232.9G — OS drive (BTRFS)
#   - 2x 3.6TB HDD — media storage via mergerfs (/data)
#
# Enabled modules:
#   - AMD drivers
#   - base/common.nix
#   - samba.nix (media, shared, downloads shares)
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    ../../modules/base/common.nix
    ../../modules/base/linuxury-ssh.nix
    ../../modules/base/auto-update.nix
    ../../modules/hardware/drivers.nix
    ../../modules/services/samba.nix
  ];

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Media-Server";

  # =========================================================================
  # GPU driver selection
  # AMD RX 480 — used for VAAPI hardware transcoding via Plex
  # =========================================================================
  hardware.gpu = "amd";

  # =========================================================================
  # Filesystem — NVMe OS drive with BTRFS subvolumes
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

    # -----------------------------------------------------------------------
    # Individual HDD mounts — these feed into mergerfs
    # Both drives are ext4 formatted with labels disk1 and disk2
    # -----------------------------------------------------------------------
    "/mnt/disk1" = {
      device  = "/dev/disk/by-label/disk1";
      fsType  = "ext4";
      options = [ "noatime" "user_xattr" ];
    };

    "/mnt/disk2" = {
      device  = "/dev/disk/by-label/disk2";
      fsType  = "ext4";
      options = [ "noatime" "user_xattr" ];
    };

    # -----------------------------------------------------------------------
    # mergerfs — combines both HDDs into a single /data mount point
    #
    # From the outside /data looks like one 7.2TB drive.
    # mergerfs handles distributing files across the two physical drives
    # transparently using the "most free space" policy.
    #
    # Options explained:
    #   cache.files=partial   — partial caching for better performance
    #   dropcacheonclose=true — frees memory cache when files are closed
    #   category.create=mfs   — write new files to drive with most free space
    #   moveonenospc=true     — move files to other drive if one fills up
    #   minfreespace=10G      — always keep 10GB free on each drive
    #   nofail                — boot even if drives are missing
    # -----------------------------------------------------------------------
    "/data" = {
      device  = "/mnt/disk1:/mnt/disk2";
      fsType  = "fuse.mergerfs";
      options = [
        "cache.files=partial"
        "dropcacheonclose=true"
        "category.create=mfs"
        "moveonenospc=true"
        "minfreespace=10G"
        "nofail"
      ];
      depends = [ "/mnt/disk1" "/mnt/disk2" ];
    };
  };

  # =========================================================================
  # Swap
  # =========================================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];

  # =========================================================================
  # Kernel
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  # =========================================================================
  # Hardware video transcoding — VAAPI
  #
  # The RX 480 handles hardware transcoding for Plex.
  # Run `vainfo` after first boot to verify VAAPI is working.
  # In Plex settings enable Hardware-Accelerated Transcoding.
  # =========================================================================
  hardware.graphics = {
    enable      = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      amdvlk
      rocmPackages.clr
      libva
      libva-utils   # vainfo command — verify VAAPI after first boot
    ];
  };

  # =========================================================================
  # Service groups
  #
  # These groups control file permissions across all media services.
  # Each service runs under its own user but shares the media group
  # for read/write access to /data/media and related folders.
  # =========================================================================
  users.groups = {
    media        = {};  # Shared group for all media services
    arr-services = {};  # Shared group for all arr services
  };

  # =========================================================================
  # Storage directory structure
  #
  # systemd-tmpfiles creates and manages these directories at boot.
  # They are recreated automatically if accidentally deleted.
  # =========================================================================
  systemd.tmpfiles.rules = [
    # Media library — Plex and Arr services read from here
    "d /data/media                        0775 root media        -"
    "d /data/media/movies                 0775 root media        -"
    "d /data/media/tv                     0775 root media        -"
    "d /data/media/anime                  0775 root media        -"
    "d /data/media/music                  0775 root media        -"
    "d /data/media/books                  0775 root media        -"

    # Downloads — Arr services write here, then move to media
    "d /data/downloads                    0775 root media        -"
    "d /data/downloads/complete           0775 root media        -"
    "d /data/downloads/incomplete         0775 root media        -"

    # Photos — Immich library
    "d /data/photos                       0775 root media        -"
    "d /data/photos/library               0755 root media        -"
    "d /data/photos/uploads               0755 root media        -"
    "d /data/photos/thumbs                0755 root media        -"
    "d /data/photos/profile               0755 root media        -"
    "d /data/photos/backups               0755 root media        -"

    # Shared workspace — accessible to all family via Samba
    "d /data/shared                       0775 root media        -"

    # Service config directories — persistent app data
    "d /data/config                       0755 root         root         -"
    "d /data/config/plex                  0755 plex         media        -"
    "d /data/config/immich                0755 root         root         -"
    "d /data/config/arr-services          0755 root         arr-services -"
    "d /data/config/arr-services/sonarr   0755 sonarr       arr-services -"
    "d /data/config/arr-services/radarr   0755 radarr       arr-services -"
    "d /data/config/arr-services/prowlarr 0755 prowlarr     arr-services -"
    "d /data/config/arr-services/bazarr   0755 bazarr       arr-services -"
    "d /data/config/arr-services/readarr  0755 readarr      arr-services -"
    "d /data/config/arr-services/lidarr   0755 lidarr       arr-services -"
  ];

  # =========================================================================
  # Plex Media Server
  #
  # Web UI available at http://Media-Server:32400/web after first boot.
  #
  # After first boot:
  #   1. Open the Plex web UI and complete setup
  #   2. Enable Hardware-Accelerated Transcoding in settings
  #   3. Point libraries at /data/media/movies, /data/media/tv etc
  #   4. Point Plex transcoder at jellyfin-ffmpeg for VAAPI support
  # =========================================================================
  services.plex = {
    enable       = true;
    openFirewall = true;
    user         = "plex";
    group        = "media";
    dataDir      = "/data/config/plex";
  };

  # =========================================================================
  # Arr stack — automated media management
  #
  # Web UIs after first boot:
  #   Prowlarr → http://Media-Server:9696
  #   Sonarr   → http://Media-Server:8989
  #   Radarr   → http://Media-Server:7878
  #   Lidarr   → http://Media-Server:8686
  #   Readarr  → http://Media-Server:8787
  #   Bazarr   → http://Media-Server:6767
  # =========================================================================
  services.sonarr = {
    enable  = true;
    user    = "sonarr";
    group   = "arr-services";
    dataDir = "/data/config/arr-services/sonarr";
  };

  services.radarr = {
    enable  = true;
    user    = "radarr";
    group   = "arr-services";
    dataDir = "/data/config/arr-services/radarr";
  };

  services.prowlarr = {
    enable = true;
    # Note: dataDir not configurable in nixpkgs yet
    # defaults to /var/lib/prowlarr
  };

  services.lidarr = {
    enable  = true;
    user    = "lidarr";
    group   = "arr-services";
    dataDir = "/data/config/arr-services/lidarr";
  };

  services.readarr = {
    enable  = true;
    user    = "readarr";
    group   = "arr-services";
    dataDir = "/data/config/arr-services/readarr";
  };

  services.bazarr = {
    enable = true;
    user   = "bazarr";
    group  = "arr-services";
  };

  # =========================================================================
  # Immich — Self-hosted photo and video management
  #
  # Web UI available at http://Media-Server:2283 after first boot.
  #
  # After first boot:
  #   1. Create admin account at the web UI
  #   2. Configure external library at /data/photos/library
  # =========================================================================
  services.immich = {
    enable        = true;
    openFirewall  = true;
    mediaLocation = "/data/photos";
  };

  # =========================================================================
  # Open firewall ports for all services
  # =========================================================================
  networking.firewall.allowedTCPPorts = [
    32400  # Plex
    8989   # Sonarr
    7878   # Radarr
    9696   # Prowlarr
    8686   # Lidarr
    8787   # Readarr
    6767   # Bazarr
    2283   # Immich
  ];

  # =========================================================================
  # Give Plex access to GPU for transcoding
  # =========================================================================
  users.groups.render.members = [ "plex" ];
  users.groups.video.members  = [ "plex" ];

  # =========================================================================
  # Disable audio
  # =========================================================================
  services.pipewire.enable    = lib.mkForce false;
  sound.enable                = lib.mkForce false;
  hardware.pulseaudio.enable  = lib.mkForce false;

  # =========================================================================
  # Disable suspend/sleep
  # =========================================================================
  systemd.targets.sleep.enable        = false;
  systemd.targets.suspend.enable      = false;
  systemd.targets.hibernate.enable    = false;
  systemd.targets.hybrid-sleep.enable = false;

  services.logind.extraConfig = ''
    HandleSuspendKey=ignore
    HandleHibernateKey=ignore
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    IdleAction=ignore
  '';

  # =========================================================================
  # Server network optimizations
  # =========================================================================
  boot.kernel.sysctl = {
    "net.core.rmem_max"               = 134217728;
    "net.core.wmem_max"               = 134217728;
    "net.ipv4.tcp_rmem"               = "4096 87380 134217728";
    "net.ipv4.tcp_wmem"               = "4096 65536 134217728";
    "net.core.netdev_max_backlog"     = 5000;
    "fs.inotify.max_user_watches"     = 524288;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc"          = "fq";
  };

  # =========================================================================
  # Packages
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Monitoring
    iotop
    nethogs
    ncdu
    smartmontools
    rsync
    rclone
    tmux
    lsof
    strace

    # Media tools
    jellyfin-ffmpeg  # FFmpeg with VAAPI support for Plex transcoding
    mediainfo        # Inspect media file details
    mkvtoolnix       # MKV container tools
    ffmpeg           # General media conversion

    # Storage
    mergerfs         # CLI access to mergerfs pool
  ];

  # =========================================================================
  # Samba shares
  #
  # Global Samba config (security, protocol, discovery) is in samba.nix.
  # Here we define what this specific server actually shares.
  #
  # Share layout:
  #   media     — /data/media    — all users read, linuxury can write
  #   shared    — /data/shared   — all users read/write (family drop-box)
  #   downloads — /data/downloads — linuxury + babylinux read/write
  #
  # After first boot, set Samba passwords (separate from Linux password):
  #   sudo smbpasswd -a linuxury
  #   sudo smbpasswd -a babylinux
  #   sudo smbpasswd -a alex
  #
  # Access from clients:
  #   Windows:  \\Media-Server\media
  #   macOS:    smb://Media-Server/media
  #   Linux:    smb://Media-Server/media
  # =========================================================================
  services.samba.shares = {

    # -----------------------------------------------------------------------
    # media — the main library (movies, TV, music, books, anime)
    #
    # All family members can browse and read.
    # Only linuxury can write — library management is your job.
    # alex and babylinux won't accidentally delete or move things.
    # -----------------------------------------------------------------------
    media = {
      path           = "/data/media";
      comment        = "Media library";
      browseable     = "yes";
      "read only"    = "yes";
      "write list"   = "linuxury";
      "valid users"  = "linuxury babylinux alex";
      # Ensure new files created by linuxury are readable by the group
      "create mask"      = "0664";
      "directory mask"   = "0775";
      "force group"      = "media";
    };

    # -----------------------------------------------------------------------
    # shared — family shared workspace
    #
    # Everyone can put files here and see each other's files.
    # Good for: photos to share, documents, school stuff, etc.
    # -----------------------------------------------------------------------
    shared = {
      path          = "/data/shared";
      comment       = "Shared family folder";
      browseable    = "yes";
      "read only"   = "no";
      "valid users" = "linuxury babylinux alex";
      "force group" = "media";
      "create mask"     = "0664";
      "directory mask"  = "0775";
    };

    # -----------------------------------------------------------------------
    # downloads — torrent staging area
    #
    # Where completed downloads land before being moved to the media library.
    # linuxury and babylinux can access (she downloads via VPN on her machines,
    # but she might want to browse completed downloads from here too).
    # alex has no access — nothing here is appropriate for a 6 year old.
    # -----------------------------------------------------------------------
    downloads = {
      path          = "/data/downloads";
      comment       = "Download staging";
      browseable    = "yes";
      "read only"   = "no";
      "valid users" = "linuxury babylinux";
      "force group" = "media";
      "create mask"     = "0664";
      "directory mask"  = "0775";
    };

  };

  # =========================================================================
  # Users — three family accounts for Samba
  # =========================================================================
  users.users = {
    linuxury = {
      isNormalUser = true;
      description  = "Linuxury";
      extraGroups  = [ "wheel" "networkmanager" "video" "render" "media" ];
      shell        = pkgs.fish;
    };

    babylinux = {
      isNormalUser = true;
      description  = "BabyLinux";
      extraGroups  = [ "networkmanager" "media" ];
      shell        = pkgs.fish;
    };

    alex = {
      isNormalUser = true;
      description  = "Alex";
      extraGroups  = [ "media" ];
      shell        = pkgs.fish;
    };
  };

  programs.fish.enable = true;
}
