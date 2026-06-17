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
#   - Hyprland + Wayle + SDDM (active)
#   - MangoWC + Noctalia (disabled — VRR/wlroots assertion crash on RDNA3)
#   - COSMIC (disabled)
#   - Niri (disabled)
#   - Gaming
#   - Development
# ===========================================================================

{
  pkgs,
  ...
}:

{
  imports = [
    # ==============================================================
    # System
    #   core     — locale, fonts, nix daemon, base CLI, boot defaults
    #   graphical — Wayland stack, PipeWire audio, XDG portals, base pkgs
    # ==============================================================
    ../../modules/system/core/default.nix
    ../../modules/system/graphical/default.nix

    # ==============================================================
    # Hardware
    #   drivers — GPU (AMD/NVIDIA/Intel) + OpenCL/VAAPI
    #   (openrgb / lemokey-keychron are option-gated — see Hardware toggles)
    # ==============================================================
    ../../modules/hardware/drivers/default.nix

    # ==============================================================
    # Graphical Apps — all optional, comment out to remove
    #   zen-browser  — primary browser (privacy-focused Firefox fork)
    #   thunderbird  — email client
    #   libreoffice  — office suite
    #   fluxer       — Discord client
    #   kdeconnect   — phone integration
    #   zennotes     — keyboard-first Markdown notes (connects to Media-Server:7879)
    # ==============================================================
    ../../modules/system/graphical/zen-browser/default.nix
    ../../modules/system/graphical/thunderbird/default.nix
    ../../modules/system/graphical/zennotes/default.nix
    ../../modules/system/graphical/libreoffice/default.nix
    ../../modules/system/graphical/fluxer/default.nix
    ../../modules/services/kdeconnect/default.nix
    #../../modules/system/graphical/firefox/default.nix
    #../../modules/system/graphical/helium/default.nix

    # ==============================================================
    # Desktop Environment — enable ONE (includes shell + greeter)
    # ==============================================================
    #../../modules/desktops/cosmic/default.nix
    #../../modules/desktops/gnome/default.nix
    #../../modules/desktops/kde/default.nix

    # ==============================================================
    # Compositor — enable ONE, pair with Shell + Greeter below
    #   mangowc disabled — VRR/wlroots assertion crash on RDNA3
    # ==============================================================
    ../../modules/compositors/hyprland/default.nix
    #../../modules/compositors/mangowc/default.nix
    #../../modules/compositors/niri/default.nix

    # ==============================================================
    # Shell — enable ONE for the active compositor
    #   dms      — bundles its own greeter, skip Greeter section
    #   wayle    — needs greeters/sddm
    #   noctalia — needs greeters/sddm
    # ==============================================================
    #../../modules/shells/wayle/default.nix
    #../../modules/shells/dms/default.nix
    ../../modules/shells/noctalia/default.nix

    # ==============================================================
    # Greeter — skip if using dms (it bundles its own)
    # ==============================================================
    ../../modules/greeters/sddm/default.nix

    # ==============================================================
    # Components — individual desktop components
    #   only needed with bare compositors not using a full shell
    # ==============================================================
    #../../modules/components/bar/waybar/default.nix
    #../../modules/components/launcher/wofi/default.nix
    #../../modules/components/notifications/swaync/default.nix

    # ==============================================================
    # Gaming
    #   Steam, Proton/Wine, Lutris, MangoHud, gamemode, controllers
    # ==============================================================
    ../../modules/gaming/default.nix

    # ==============================================================
    # Development — AI Tools
    #   ai-tools  — base: nix-ld, uv, ffmpeg (import alongside tools below)
    #   claude    — Claude Code CLI + VSCodium extension
    #   opencode  — OpenCode CLI + VSCodium extension
    #   local-llm — Ollama + AMD ROCm (7900 XTX — 24 GB VRAM)
    #   lm-studio — GUI LLM runner (requires ai-tools)
    #   odysseus  — self-hosted AI workspace
    # ==============================================================
    ../../modules/development/ai-tools/default.nix
    ../../modules/development/ai-tools/claude/default.nix
    ../../modules/development/ai-tools/opencode/default.nix
    #../../modules/development/ai-tools/local-llm/default.nix
    #../../modules/development/ai-tools/lm-studio/default.nix
    #../../modules/development/ai-tools/odysseus/default.nix

    # ==============================================================
    # Development — Editors
    #   neovim   — full IDE: normie-nvim, LSPs, opencode-nvim, claude wrapper
    #   vscodium — GUI editor: Catppuccin theme, Claude Code + OpenCode extensions
    #   zed      — fast Wayland-native editor (Rust), vim mode
    # ==============================================================
    ../../modules/development/editors/neovim/default.nix
    ../../modules/development/editors/vscodium/default.nix
    ../../modules/development/editors/zed/default.nix

    # ==============================================================
    # Development — Languages
    #   python — python3, poetry, ruff, httpie
    #   rust   — rustup toolchain, cargo tools, just
    # ==============================================================
    ../../modules/development/languages/python/default.nix
    ../../modules/development/languages/rust/default.nix

    # ==============================================================
    # Services
    #   auto-update — weekly nixos-rebuild from GitHub
    #   syncthing   — vault + nixos-config sync (linuxury pair)
    #   snapper     — BTRFS automatic snapshots
    # ==============================================================
    ../../modules/services/auto-update/default.nix
    ../../modules/services/syncthing/default.nix
    #../../modules/services/snapper/default.nix
    #../../modules/services/wallpaper-slideshow/default.nix
    #../../modules/services/samba/default.nix
    #../../modules/services/ntfy/default.nix
    #../../modules/services/vpn-qbittorrent/default.nix
    #../../modules/services/syncthing-babylinux/default.nix

    # ==============================================================
    # Users
    #   ssh         — authorized keys for this host
    #   description — GECOS display name (agenix secret)
    #   packages    — per-user package set
    # ==============================================================
    ../../modules/users/linuxury/ssh/default.nix
    ../../modules/users/linuxury/description/default.nix
    ../../modules/users/linuxury/packages/default.nix
  ];

  # ==============================================================
  # Host identity
  # ==============================================================
  networking.hostName = "Ryzen5900x";

  # ==============================================================
  # Auto-update — primary host
  #
  # This machine owns the nixpkgs update cycle. On session start it runs
  # nix flake update, rebuilds from the local repo, then commits and pushes
  # the updated flake.lock so every other host gets new packages too.
  # ==============================================================
  services.nixos-auto-update.isPrimary = true;

  # ==============================================================
  # Local LLM — AMD ROCm configuration for the RX 7900 XTX
  #
  # gfxVersion: RDNA3 (gfx1100) reports as 11.0.0
  # Find yours: rocminfo | grep gfx
  #
  # Disabled — uncomment the local-llm module import above first
  # ==============================================================
  # services.localLlm = {
  #   enable     = true;
  #   user       = "linuxury";
  #   model      = "qwen2.5:14b";
  #   gfxVersion = "11.0.0";
  # };

  # ==============================================================
  # Default session — tells SDDM which session to pre-select at login
  # ==============================================================
  services.displayManager.defaultSession = "hyprland-session";

  # ==============================================================
  # Network — prefer ethernet, auto-disable WiFi when ethernet is up
  #
  # Having both interfaces active on the same subnet causes duplicate packets
  # and routing confusion, which breaks browsers even on fast connections.
  # This dispatcher script disables WiFi as soon as ethernet connects, and
  # re-enables it if ethernet goes down (e.g. cable unplugged).
  # ==============================================================
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

  # ==============================================================
  # GPU driver selection
  # ==============================================================
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  hardware.openrgb.enable = true;
  hardware.lemokey-keychron.enable = true;

  # ==============================================================
  # Filesystem — BTRFS with subvolumes
  #
  # Desktop has no LUKS — BTRFS sits directly on the partition.
  # ==============================================================
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

  # ==============================================================
  # Drive ownership — ensure linuxury owns the XFS drive roots
  #
  # tmpfiles.d alone is unreliable here: it may run before the drives are
  # mounted, setting ownership on the bare mount-point directory instead of
  # the XFS root inode. The systemd service below explicitly waits for the
  # mount units to complete, then chowns the filesystem root correctly.
  # tmpfiles rules are kept to create the directories on first boot if needed.
  # ==============================================================
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

  # ==============================================================
  # Agenix secrets
  # ==============================================================
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

  # ==============================================================
  # Swap
  # ==============================================================
  swapDevices = [
    {
      device = "/swap/swapfile";
    }
  ];

  # ==============================================================
  # Kernel — Zen
  #
  # Zen patches mainline with lower-latency preemption, scheduler tweaks,
  # and throughput optimizations — ideal for a gaming desktop.
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

  # ==============================================================
  # AMD Radeon RX 7900 XTX specific settings
  #
  # The 7900 XTX is an RDNA3 card. These settings unlock its full
  # potential on Linux.
  # ==============================================================

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

  # ==============================================================
  # CoreCtrl — GPU and CPU control
  #
  # CoreCtrl gives you a GUI to manage AMD GPU power profiles,
  # fan curves, and CPU frequency scaling. Think of it as the
  # Linux equivalent of AMD's own Adrenalin software.
  #
  # The polkit rule below lets you use CoreCtrl without needing
  # to enter your password every time it applies settings.
  # ==============================================================
  programs.corectrl.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  # ==============================================================
  # Multi-monitor support
  #
  # arandr gives a GUI for arranging monitors.
  # autorandr remembers and restores monitor layouts automatically.
  # ==============================================================
  environment.systemPackages = with pkgs; [
    arandr # GUI monitor arrangement tool
    autorandr # Automatic monitor layout switching
    cifs-utils # Required for CIFS/Samba mounts
    xfsprogs # XFS filesystem tools (mkfs.xfs, xfs_repair, etc.)
    # corectrl is installed by programs.corectrl.enable above
  ];

  # ==============================================================
  # User account
  # ==============================================================
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

  # ==============================================================
  # Tailscale — system daemon required for Home Manager's tailscale service
  # After first boot: sudo tailscale up
  # ==============================================================
  services.tailscale.enable = true;

  programs.zsh.enable = true;
}
