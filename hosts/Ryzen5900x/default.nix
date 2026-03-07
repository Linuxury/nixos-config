# ===========================================================================
# hosts/Ryzen5900x/default.nix — AMD Ryzen 9 5900x Desktop
#
# Owner: linuxury
# Hardware: AMD Ryzen 9 5900x, AMD Radeon RX 7900 XTX
# Type: Desktop — no encryption, full performance
# Role: Personal daily driver desktop
#
# Enabled modules:
#   - AMD drivers
#   - COSMIC (default DE)
#   - Hyprland (experimentation)
#   - Niri (experimentation)
#   - Gaming
#   - Development
# ===========================================================================

{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  # Logical CPU count (threads) on this machine.
  # Used to cap parallel Nix builds — each large package (LLVM, chromium, etc.)
  # can consume 4-8 GB RAM per job, so unconstrained builds cause OOM crashes.
  numThreads = 24; # Ryzen 9 5900x: 12 cores / 24 threads

  # Allow at most 1/4 of threads as parallel Nix build jobs.
  # 24 / 4 = 6 — enough throughput while leaving RAM headroom.
  nixBuildJobs = builtins.div numThreads 4;
in

{
  imports = [
    # -------------------------------------------------------------------------
    # No nixos-hardware profile needed for a custom desktop build —
    # generic AMD support is handled by our drivers module perfectly fine.
    # -------------------------------------------------------------------------
    ../../modules/base/common.nix
    ../../modules/base/graphical-base.nix
    ../../modules/base/linuxury-ssh.nix
    ../../modules/base/linuxury-description.nix
    ../../modules/hardware/drivers.nix
    ../../modules/desktop-environments/cosmic.nix
    #../../modules/desktop-environments/hyprland.nix
    #../../modules/desktop-environments/niri.nix
    ../../modules/gaming/gaming.nix
    ../../modules/development/development.nix
    ../../modules/base/auto-update.nix
    #../../modules/services/local-llm.nix
    ../../modules/users/linuxury-packages.nix
  ];

  # =========================================================================
  # Nix build limits
  # =========================================================================
  nix.settings.max-jobs = nixBuildJobs;

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Ryzen5900x";

  # =========================================================================
  # GPU driver selection
  # =========================================================================
  hardware.gpu = "amd";

  # =========================================================================
  # Filesystem — BTRFS with subvolumes
  #
  # Desktop has no LUKS — BTRFS sits directly on the partition.
  # =========================================================================
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@home"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@nix"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/var/log" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@log"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/var/cache" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@cache"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@snapshots"
        "compress=zstd:1"
        "noatime"
      ];
    };

    "/swap" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@swap"
        "noatime"
      ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };

    "/mnt/Warehouse" = {
      device = "/dev/disk/by-label/Warehouse";
      fsType = "xfs";
      options = [
        "defaults"
        "nofail"
        "x-gvfs-show"
      ];
    };

    "/mnt/Games" = {
      device = "/dev/disk/by-label/Games";
      fsType = "xfs";
      options = [
        "defaults"
        "nofail"
        "x-gvfs-show"
      ];
    };

    # -----------------------------------------------------------------------
    # Media-Server Samba share (10.0.0.3)
    # Credentials decrypted by agenix to /run/agenix/smb-credentials
    #
    # Single share exposing /data — media/, shared/, downloads/ appear
    # as subdirectories. Filesystem permissions on the server enforce
    # per-folder access control.
    #
    # noauto: never mounted at boot or during nixos-rebuild switch.
    # _netdev + nofail: safe ordering, non-fatal if server is offline.
    # x-gvfs-show is intentionally omitted — the share appears in COSMIC
    # Files under Networks via Avahi discovery when the server is online.
    # Mount manually with: sudo mount /mnt/Media-Server
    # -----------------------------------------------------------------------
    "/mnt/Media-Server" = {
      device = "//10.0.0.3/Media-Server";
      fsType = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=1000"
        "gid=100"
        "nofail"
        "_netdev"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=5s"
      ];
    };

    # -----------------------------------------------------------------------
    # MinisForum Samba share — game server file management
    # Automounts on first access, disconnects after 60s idle.
    # Mount manually with: sudo mount /mnt/MinisForum
    # -----------------------------------------------------------------------
    "/mnt/MinisForum" = {
      device = "//10.0.0.7/GameServers";
      fsType = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=1000"
        "gid=100"
        "nofail"
        "_netdev"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=5s"
      ];
    };

    # -----------------------------------------------------------------------
    # Radxa-X4 Samba share — torrent downloads
    # Automounts on first access, disconnects after 60s idle.
    # Mount manually with: sudo mount /mnt/Torrents
    # -----------------------------------------------------------------------
    "/mnt/Torrents" = {
      device = "//10.0.0.5/Torrents";
      fsType = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=1000"
        "gid=100"
        "nofail"
        "_netdev"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=5s"
      ];
    };
  };

  # =========================================================================
  # Drive ownership — ensure linuxury owns the XFS drive roots
  #
  # tmpfiles.d alone is unreliable here: it may run before the drives are
  # mounted, setting ownership on the bare mount-point directory instead of
  # the XFS root inode. The systemd service below explicitly waits for the
  # mount units to complete, then chowns the filesystem root correctly.
  # tmpfiles rules are kept to create the directories on first boot if needed.
  # =========================================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Warehouse    0755 linuxury users -"
    "d /mnt/Games        0755 linuxury users -"
    "d /mnt/Media-Server 0755 linuxury users -"
    "d /mnt/MinisForum   0755 linuxury users -"
    "d /mnt/Torrents     0755 linuxury users -"
  ];

  systemd.services."xfs-drive-ownership" = {
    description = "Set linuxury ownership on XFS drive roots";
    after = [
      "mnt-Warehouse.mount"
      "mnt-Games.mount"
    ];
    requires = [
      "mnt-Warehouse.mount"
      "mnt-Games.mount"
    ];
    wantedBy = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "xfs-drive-ownership" ''
        chown linuxury:users /mnt/Warehouse
        chown linuxury:users /mnt/Games
        chmod 755 /mnt/Warehouse
        chmod 755 /mnt/Games
      '';
    };
  };

  # =========================================================================
  # Agenix secrets
  # =========================================================================
  age.secrets.smb-credentials = {
    file = ../../secrets/smb-credentials.age;
    mode = "0400";
    owner = "root";
  };

  # =========================================================================
  # Swap
  # =========================================================================
  swapDevices = [
    {
      device = "/swap/swapfile";
    }
  ];

  # =========================================================================
  # Kernel — Zen
  #
  # Zen patches mainline with lower-latency preemption, scheduler tweaks,
  # and throughput optimizations — ideal for a gaming desktop.
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # =========================================================================
  # AMD Radeon RX 7900 XTX specific settings
  #
  # The 7900 XTX is an RDNA3 card. These settings unlock its full
  # potential on Linux.
  # =========================================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff" # Unlocks all power management features
    # Required for full fan curve and
    # overclock control via corectrl
  ];

  # =========================================================================
  # OpenRGB — RGB lighting control
  #
  # Controls RGB LEDs on the motherboard, RAM, and peripherals.
  # The NixOS module installs the udev rules so OpenRGB can access
  # USB and SMBus controllers without root.
  # =========================================================================
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd"; # Loads the i2c-piix4 SMBus driver for AMD motherboards
  };

  # =========================================================================
  # CoreCtrl — GPU and CPU control
  #
  # CoreCtrl gives you a GUI to manage AMD GPU power profiles,
  # fan curves, and CPU frequency scaling. Think of it as the
  # Linux equivalent of AMD's own Adrenalin software.
  #
  # The polkit rule below lets you use CoreCtrl without needing
  # to enter your password every time it applies settings.
  # =========================================================================
  programs.corectrl = {
    enable = true;
    gpuOverclock.enable = true; # Allows GPU overclock controls in CoreCtrl
  };

  # =========================================================================
  # Multi-monitor support
  #
  # arandr gives a GUI for arranging monitors.
  # autorandr remembers and restores monitor layouts automatically.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    arandr # GUI monitor arrangement tool
    autorandr # Automatic monitor layout switching
    cifs-utils # Required for CIFS/Samba mounts
    xfsprogs # XFS filesystem tools (mkfs.xfs, xfs_repair, etc.)
    # corectrl is installed by programs.corectrl.enable above
  ];

  # =========================================================================
  # User account
  # =========================================================================
  users.users.linuxury = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "gamemode"
    ];
    shell = pkgs.fish;
  };

  # =========================================================================
  # Tailscale — system daemon required for Home Manager's tailscale service
  # After first boot: sudo tailscale up
  # =========================================================================
  services.tailscale.enable = true;

  programs.fish.enable = true;
}
