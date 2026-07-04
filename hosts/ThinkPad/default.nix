# ===========================================================================
# hosts/ThinkPad/default.nix — Lenovo ThinkPad T14s Gen 4 (AMD)
#
# Owner: linuxury
# Hardware: AMD Ryzen 7 PRO 7840U, Radeon 780M iGPU
# Type: Laptop — LUKS encrypted, power managed
# Role: Personal daily driver
#
# Enabled modules:
#   - AMD drivers
#   - COSMIC Desktop (active DE — cosmic-greeter)
#   - Hyprland / Niri / GNOME / KDE (available — commented out, one at a time)
#   - Gaming
#   - Development
# ===========================================================================

{
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [
    # ==============================================================
    # System
    #   nixos-hardware — ThinkPad T14s AMD Gen4: thermal, power, fingerprint
    #   core           — locale, fonts, nix daemon, base CLI, boot defaults
    #   graphical      — Wayland stack, PipeWire audio, XDG portals, base pkgs
    # ==============================================================
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14s-amd-gen4
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
    ../../modules/desktops/cosmic/default.nix
    #../../modules/desktops/gnome/default.nix
    #../../modules/desktops/kde/default.nix

    # ==============================================================
    # Compositor — enable ONE, pair with Shell + Greeter below
    # ==============================================================
    #../../modules/compositors/hyprland/default.nix
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
    #../../modules/shells/noctalia/default.nix

    # ==============================================================
    # Greeter — skip if using dms or a full DE (they bundle their own)
    # ==============================================================
    #../../modules/greeters/sddm/default.nix

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
    #   local-llm — Ollama + ROCm (disabled — laptop VRAM too limited)
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
    #   neovim   — full IDE: custom config, LSPs, opencode-nvim, claude wrapper
    #   vscodium — GUI editor: Catppuccin theme, Claude Code + OpenCode extensions
    #   zed      — fast Wayland-native editor (Rust), vim mode
    # ==============================================================
    ../../modules/development/editors/neovim/default.nix
    ../../modules/development/editors/vscodium/default.nix
    #../../modules/development/editors/zed/default.nix

    # ==============================================================
    # Development — Languages
    #   python — python3, poetry, ruff, httpie
    #   rust   — rustup toolchain, cargo tools, just
    # ==============================================================
    ../../modules/development/languages/python/default.nix
    #../../modules/development/languages/rust/default.nix

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
  networking.hostName = "ThinkPad";

  # ==============================================================
  # GPU driver selection — tells drivers.nix which profile to use
  # ==============================================================
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = true;

  # ==============================================================
  # SwayNC Control Panel — hardware capabilities (Hyprland only)
  # Uncomment when hyprland.nix is active.
  #
  # Verify device names on first boot:
  #   ls /sys/class/backlight/   → confirm backlightDevice
  #   ls /sys/class/leds/ | grep kbd → confirm kbBacklightDevice
  # ==============================================================
  # myModules.swaync.hasBacklight      = true;
  # myModules.swaync.backlightDevice   = "amdgpu_bl1";  # typical AMD ThinkPad T14s
  # myModules.swaync.hasKbBacklight    = true;
  # myModules.swaync.kbBacklightDevice = "tpacpi::kbd_backlight";
  # myModules.swaync.hasWifi           = true;
  # myModules.swaync.hasBluetooth      = true;

  # ==============================================================
  # LUKS — Full disk encryption
  #
  # The BTRFS partition sits inside a LUKS container.
  # You'll be prompted for this passphrase before the system boots.
  # The label "nixos-luks" refers to the raw encrypted partition.
  # After unlocking, it becomes available as /dev/mapper/cryptroot
  # which is where our BTRFS filesystem lives.
  # ==============================================================
  boot.initrd.luks.devices."cryptroot" = {
    # We reference by label so it works regardless of whether the drive
    # is nvme0n1, nvme1n1, or any other device name
    device = "/dev/disk/by-label/nixos-luks";
    allowDiscards = true;
    # Enables TRIM on the SSD through LUKS
    # Important for SSD longevity and performance
  };

  # Early KMS — load the AMD GPU driver inside initrd so Plymouth gets a real
  # framebuffer before the root filesystem is mounted. Without this, Plymouth
  # falls back to the VGA text console and the LUKS passphrase prompt appears
  # as a tiny line at the top of the screen instead of a centered graphical UI.
  boot.initrd.kernelModules = [ "amdgpu" ];

  # ==============================================================
  # Filesystem — BTRFS with subvolumes
  #
  # All subvolumes live on the LUKS container (cryptroot).
  # Labels reference what we set during installation.
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
      # No compression on swap — compressed swap causes issues
    };

    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
      # Restrictive permissions on /boot for security
    };

    # -----------------------------------------------------------------------
    # Media-Server Samba share
    # Automounts on first access, disconnects after 60s idle.
    # nofail: non-fatal if the server is offline (e.g. away from home).
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
      ];
    };

    # -----------------------------------------------------------------------
    # MinisForum Samba share — game server file management
    # Automounts on first access, disconnects after 60s idle.
    # nofail: non-fatal if the server is offline (e.g. away from home).
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
      ];
    };

  };

  # ==============================================================
  # CIFS tools — required for Samba/SMB mounts
  # ==============================================================
  environment.systemPackages = with pkgs; [
    cifs-utils

    # ==============================================================
    # Host-specific apps
    # Special tools only this machine needs — editors, design tools,
    # video editors, image editors, etc. go here, NOT in the shared
    # user packages module, so each host can enable/disable them
    # independently.
    # ==============================================================
    # affinity-v3  # re-enable when vc_redist.x64.exe CDN recovers (Microsoft 503s as of 2026-07-04)
                  # Affinity Photo + Designer + Publisher via Wine
                  # First run opens installer — leave path at default.
                  # Data: ~/.local/share/affinity-v3/ | Update: affinity-v3 update
  ];

  # ==============================================================
  # Mount point directory
  # ==============================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 linuxury users -"
    "d /mnt/MinisForum   0755 linuxury users -"
    "d /mnt/Torrents     0755 linuxury users -"
  ];

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
  # and throughput optimizations — great for both gaming and day-to-day
  # desktop responsiveness on a laptop.
  # ==============================================================
  # boot.kernelPackages = pkgs.linuxPackages_latest;         # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  boot.kernelPackages = pkgs.linuxPackages_zen;             # Zen

  # ==============================================================
  # Power management — critical for laptop battery life
  #
  # TLP is a comprehensive power management tool that automatically
  # applies optimized settings for battery vs AC power.
  # ==============================================================
  services.tlp = {
    enable = true;
    settings = {
      # CPU scaling governor
      CPU_SCALING_GOVERNOR_ON_AC = "performance"; # Full speed on charger
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave"; # Save battery on battery

      # AMD CPU power management
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Keep battery between 75-95% — charges whenever plugged in and below
      # 75%, stops at 95% so there's plenty of charge if you need to head out.
      # ThinkPads support this natively via the embedded controller.
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 95;

      # PCIe power management
      PCIE_ASPM_ON_BAT = "powersupersave";
    };
  };

  # Prevent TLP and power-profiles-daemon from conflicting
  services.power-profiles-daemon.enable = false;

  # ==============================================================
  # Touchpad — libinput
  #
  # libinput is the modern input driver for touchpads on Linux.
  # These settings give a comfortable laptop touchpad experience.
  # ==============================================================
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true; # Tap to click
      naturalScrolling = true; # Reverse scroll direction (like macOS/modern default)
      scrollMethod = "twofinger";
      middleEmulation = true; # Three finger tap = middle click
      disableWhileTyping = true; # Disable touchpad while typing to avoid accidental input
    };
  };

  # ==============================================================
  # Fingerprint reader — fprintd
  #
  # The T14s G4 has a fingerprint reader supported by fprintd.
  # After installation, enroll your finger with:
  #   fprintd-enroll
  #
  # Then you can use your fingerprint for:
  #   - sudo authentication
  #   - login screen authentication
  # ==============================================================
  services.fprintd.enable = true;

  # Allow PAM (authentication system) to use fingerprint as an auth method.
  # mkForce needed: GDM sets login.fprintAuth = false by default.
  security.pam.services = {
    login.fprintAuth = lib.mkForce true;
    sudo.fprintAuth = true;
    polkit-1.fprintAuth = true;
  };

  # ==============================================================
  # Firmware — required for WiFi (Qualcomm QCNFA765 / ath12k)
  #
  # Without linux-firmware, the ath12k driver loads but finds no firmware
  # files and refuses to bind — leaving the WiFi adapter invisible to the
  # system. enableRedistributableFirmware pulls in linux-firmware which
  # contains the WCN7850/ath12k blobs needed for this card.
  # ==============================================================
  hardware.enableRedistributableFirmware = true;

  # ==============================================================
  # Laptop specific kernel modules
  #
  # thinkpad_acpi — fan control, hotkeys, LED control, battery events
  #
  # NOTE: acpi_call was previously included for TLP battery thresholds,
  # but the T14s Gen 4 (2022+) exposes charge thresholds natively via sysfs
  # (NATACPI interface). TLP 1.4+ uses that automatically — no acpi_call
  # needed. Loading it caused ACPI method execution during TLP restarts
  # (e.g. on nixos-rebuild switch) which could freeze the system.
  # ==============================================================
  boot.kernelModules = [ "thinkpad_acpi" ];

  # ==============================================================
  # Lid and power button behavior
  # ==============================================================
  services.logind = {
    settings.Login = {
      HandleLidSwitch = "suspend"; # Suspend when lid closes
      HandleLidSwitchExternalPower = "suspend"; # Even on AC — saves energy
      HandlePowerKey = "suspend";
      IdleAction = "suspend";
      IdleActionSec = "20min";
    };
  };

  # ==============================================================
  # User account
  #
  # This defines your system user. The password is set separately
  # (never put passwords in config files — use passwd after first boot).
  # ==============================================================
  users.users.linuxury = {
    isNormalUser = true;
    extraGroups = [
      "wheel" # sudo access
      "networkmanager" # manage network connections without sudo
      "video" # access to video devices
      "audio" # access to audio devices
      "input" # access to input devices (controllers, etc)
      "gamemode" # access to GameMode daemon
    ];
    shell = pkgs.zsh;
  };

  # ==============================================================
  # Tailscale — system daemon required for Home Manager's tailscale service
  # After first boot: sudo tailscale up
  # ==============================================================
  services.tailscale.enable = true;

  # ==============================================================
  # Zsh — enable system-wide so it's available as a login shell
  # Actual configuration lives in users/linuxury/home.nix
  # ==============================================================
  programs.zsh.enable = true;
}
