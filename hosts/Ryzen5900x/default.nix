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
#   - Hyprland + DMS (active)
#   - MangoWC + Noctalia (disabled — VRR/wlroots assertion crash on RDNA3)
#   - COSMIC (disabled)
#   - Niri (disabled)
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

{
  imports = [
    # -------------------------------------------------------------------------
    # No nixos-hardware profile needed for a custom desktop build —
    # generic AMD support is handled by our drivers module perfectly fine.
    # -------------------------------------------------------------------------
    ../../modules/system/core/default.nix
    ../../modules/system/graphical/default.nix
    ../../modules/users/linuxury/ssh/default.nix
    ../../modules/users/linuxury/description/default.nix
    ../../modules/hardware/drivers/default.nix
    #../../modules/desktops/cosmic/default.nix
    ../../modules/compositors/hyprland/default.nix
    #../../modules/desktops/niri/default.nix
    #../../modules/desktops/mangowc/default.nix
    ../../modules/gaming/default.nix
    #../../modules/development/default.nix
    ../../modules/hardware/openrgb/default.nix
    ../../modules/services/auto-update/default.nix
    #../../modules/services/local-llm/default.nix
    ../../modules/users/linuxury/packages/default.nix
    ../../modules/services/syncthing/default.nix
    ../../modules/services/ai-tools/default.nix
  ];

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Ryzen5900x";

  # =========================================================================
  # Default session — managed by greetd when mangowc.nix is active.
  # Restore this if switching back to a display manager (SDDM, GDM, etc.).
  # =========================================================================
  # services.displayManager.defaultSession = "hyprland-session";

  # =========================================================================
  # Network — prefer ethernet, auto-disable WiFi when ethernet is up
  #
  # Having both interfaces active on the same subnet causes duplicate packets
  # and routing confusion, which breaks browsers even on fast connections.
  # This dispatcher script disables WiFi as soon as ethernet connects, and
  # re-enables it if ethernet goes down (e.g. cable unplugged).
  # =========================================================================
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeText "wifi-ethernet-exclusive" ''
        #!/bin/sh
        IFACE="$1"
        STATUS="$2"

        # Only act on ethernet interfaces (enp*, eth*, eno*)
        case "$IFACE" in
          en*|eth*|eno*)
            if [ "$STATUS" = "up" ]; then
              nmcli radio wifi off
            elif [ "$STATUS" = "down" ]; then
              nmcli radio wifi on
            fi
            ;;
        esac
      '';
      type = "basic";
    }
  ];

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
        "x-systemd.mount-timeout=2s"
        "x-gvfs-hide"
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
        "x-systemd.mount-timeout=2s"
        "x-gvfs-hide"
      ];
    };

    "/mnt/Torrents" = {
      device = "//10.0.0.3/Downloads";
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
        "x-systemd.mount-timeout=2s"
        "x-gvfs-hide"
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

  age.secrets.openrouter-api-key = {
    file = ../../secrets/openrouter-api-key.age;
    mode = "0440";
    owner = "root";
    group = "users";
  };

  age.secrets.flow-icons-license = {
    file = ../../secrets/flow-icons-license.age;
    mode = "0440";
    owner = "root";
    group = "users";
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
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

  # =========================================================================
  # AMD Radeon RX 7900 XTX specific settings
  #
  # The 7900 XTX is an RDNA3 card. These settings unlock its full
  # potential on Linux.
  # =========================================================================

  # amdgpu must be loaded in the initrd so Plymouth can initialize the GPU
  # early enough to display its splash screen. Without this, Plymouth falls
  # back to a basic framebuffer that doesn't work on RDNA3, causing kernel
  # messages to bleed through despite quiet+splash being set.
  boot.initrd.kernelModules = [ "amdgpu" ];

  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff" # Unlocks all power management features
    # Required for full fan curve and
    # overclock control via corectrl

    # Suppress kernel/udev/systemd messages on the console (TTY)
    "quiet"
    "loglevel=3"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
    "rd.systemd.show_status=false"
  ];

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
  programs.corectrl.enable = true;
  hardware.amdgpu.overdrive.enable = true;

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
      "seat"   # seatd seat management (DRM/input handoff for Wayland compositors)
    ];
    shell = pkgs.zsh;

  };

  # =========================================================================
  # Tailscale — system daemon required for Home Manager's tailscale service
  # After first boot: sudo tailscale up
  # =========================================================================
  services.tailscale.enable = true;

  programs.zsh.enable = true;
}
