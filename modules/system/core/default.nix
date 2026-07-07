# ===========================================================================
# modules/system/core/default.nix — Shared base configuration for ALL hosts
#
# Every single machine in your setup (desktops, laptops, servers) imports
# this file. Think of it as the foundation everything else builds on top of.
#
# Rule of thumb: if every machine needs it, it lives here.
# If only some machines need it, it belongs in a more specific module.
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    # Automatic BTRFS snapshots + monthly scrub — runs on every host
    ../../services/snapper/default.nix
  ];
  # =========================================================================
  # BOOT — systemd-boot + Plymouth
  #
  # systemd-boot is a simple, fast UEFI bootloader. Much simpler than GRUB
  # and perfectly suited for modern machines. It reads entries from
  # /boot/loader/entries/ and lets you pick a generation at boot.
  #
  # Plymouth handles the graphical boot splash so you see a clean animation
  # instead of a wall of kernel messages during startup.
  # =========================================================================
  boot = {
    loader = {
      # Use systemd-boot instead of GRUB
      systemd-boot = {
        enable = true;
        # How many NixOS generations to keep in the boot menu.
        # Older ones get cleaned up automatically. 10 is a safe number —
        # you always have rollback options without filling up /boot.
        configurationLimit = 10;
      };
      # Allow NixOS to modify EFI variables so it can manage boot entries.
      # Required for systemd-boot to work correctly.
      efi.canTouchEfiVariables = true;

      # Boot immediately — no menu unless you hold Space at startup.
      timeout = 0;
    };

    # -----------------------------------------------------------------------
    # Plymouth — graphical boot splash
    # The theme can be overridden per host if you want different looks.
    # -----------------------------------------------------------------------
    plymouth = {
      enable = true;
      # "spinner" shows a minimal loading animation — consistent across all hosts.
      # Other options: "bgrt" (UEFI logo), "tribar", "fade-in", or a custom theme.
      # mkDefault so per-host configs can override this without needing mkForce.
      theme = lib.mkDefault "spinner";
    };

    # Make the boot process silent — hides kernel messages behind Plymouth.
    # These kernel parameters tell the system to stay quiet during boot.
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"  # Drops to a shell on failure instead of rebooting — useful for debugging
      "loglevel=3"          # Only show errors, not info messages
      "rd.udev.log_level=3" # Same for udev (device detection)
      "udev.log_priority=3"
    ];

    # -----------------------------------------------------------------------
    # Kernel — Zen (default for all hosts)
    #
    # Zen applies scheduler tweaks, lower latency preemption, and throughput
    # patches on top of mainline — ideal for interactive/gaming workloads.
    # mkDefault lets individual hosts override this (e.g. a server that
    # needs a specific LTS kernel).
    # -----------------------------------------------------------------------
    kernelPackages = lib.mkDefault pkgs.linuxPackages_zen;
  };

  # =========================================================================
  # NETWORKING
  #
  # NetworkManager handles all network connections — wired, wireless, VPN.
  # It's the standard for desktop Linux and works fine on servers too.
  # =========================================================================
  networking = {
    # NetworkManager replaces the older networking.interfaces approach.
    # It handles DHCP, WiFi, and more automatically.
    networkmanager = {
      enable = true;

      # When ethernet comes up, disable WiFi to save power and avoid split routing.
      # When ethernet goes down, re-enable WiFi so the machine stays connected.
      # No-op on hosts with no WiFi interface — the interface pattern never matches.
      dispatcherScripts = [
        {
          source = pkgs.writeShellScript "ethernet-wifi-exclusive" ''
            IFACE="$1"
            ACTION="$2"
            case "$IFACE" in
              en*|eth*|eno*)
                case "$ACTION" in
                  up)        nmcli radio wifi off ;;
                  down)      nmcli radio wifi on  ;;
                esac
                ;;
            esac
          '';
          type = "basic";
        }
      ];
    };

    # Enables the firewall. By default it blocks all incoming connections
    # except what you explicitly open. SSH is handled below via services.openssh.
    firewall = {
      enable = true;
      # Add ports here if you need to open them globally across all hosts.
      # Host-specific ports should be opened in that host's own config file.
      # allowedTCPPorts = [ ];
      # allowedUDPPorts = [ ];
    };
  };

  # =========================================================================
  # SSH — Secure Shell daemon
  #
  # Runs on all machines so you can always reach them remotely.
  # This is especially important for your headless servers.
  # =========================================================================
  services.openssh = {
    enable = true;
    settings = {
      # Disable root login over SSH — always log in as your user instead.
      # This is a basic security practice.
      PermitRootLogin = "no";
      # Disable password authentication — require SSH keys instead.
      # Much more secure. Make sure you have your SSH key set up before
      # enabling this, or you could lock yourself out.
      PasswordAuthentication = false;
    };
  };

  # =========================================================================
  # LOCALE & TIME
  #
  # Set your timezone and language here so every machine is consistent.
  # Change these values to match your location.
  # =========================================================================
  time.timeZone = "America/New_York"; # Change to your timezone

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS        = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT    = "en_US.UTF-8";
      LC_MONETARY       = "en_US.UTF-8";
      LC_NAME           = "en_US.UTF-8";
      LC_NUMERIC        = "en_US.UTF-8";
      LC_PAPER          = "en_US.UTF-8";
      LC_TELEPHONE      = "en_US.UTF-8";
      LC_TIME           = "en_US.UTF-8";
    };
  };

  # =========================================================================
  # SOUND — PipeWire
  #
  # PipeWire is the modern audio stack for Linux. It replaces PulseAudio
  # and JACK while staying compatible with both. WirePlumber is the
  # session manager that handles routing between apps and devices.
  #
  # Disabled on servers — they don't need audio.
  # That's handled by setting sound.enable = false in server host configs.
  # =========================================================================
  services.pipewire = {
    enable = true;
    # Backward compatibility layers so apps built for PulseAudio or ALSA
    # work without any changes
    alsa.enable = true;
    alsa.support32Bit = true; # Needed for some games and older software
    pulse.enable = true;      # PulseAudio compatibility
    jack.enable = true;       # JACK compatibility (for audio production tools)
    wireplumber.enable = true;
  };

  # =========================================================================
  # NIX SETTINGS
  #
  # Configuration for the Nix package manager itself.
  # =========================================================================
  # Allow unfree packages (Steam, Nvidia drivers, etc.) system-wide.
  # The flake.nix pkgs import also sets this, but that doesn't propagate
  # into NixOS module evaluation — this option is the correct way to do it.
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      # Enables the new "nix" CLI commands and flakes support.
      # Without this, flakes won't work at all.
      experimental-features = [ "nix-command" "flakes" ];

      # Binary caches — servers that provide pre-built packages.
      # Without these, Nix would compile everything from source.
      substituters = [
        "https://cache.nixos.org"           # Official NixOS cache
        "https://nix-community.cachix.org"  # Community packages
        "https://cosmic.cachix.org"         # Pre-built COSMIC packages
        # cache.garnix.io is in modules/system/graphical/affinity/default.nix
        # (graphical hosts only — servers don't need it)
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:L/J5ArMSr0xyNkTPoaFNiYmUoYMfdXZAo2MnGpvgDyU="
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85d/E="
        # cache.garnix.io key is in modules/system/graphical/affinity/default.nix
      ];

      # Allow your user to manage the Nix store without sudo for some operations
      trusted-users = [ "root" "@wheel" ];

      # Limit parallel build jobs — each heavy package (LLVM, chromium, Qt, etc.)
      # can consume 4–8 GB RAM per job. Without a cap, machines with 16–32 GB RAM
      # OOM-kill the Nix daemon during auto-updates.
      # max-jobs = 2: only 2 derivations build in parallel (memory safety).
      # cores = 0: each job uses all available CPU cores (max throughput per job).
      max-jobs = 2;
      cores = 0;
    };

    # Automatically clean up old generations and unused packages.
    # Keeps your disk from filling up with old builds over time.
    gc = {
      automatic = true;
      dates = "weekly";      # Run cleanup every week
      options = "--delete-older-than 30d"; # Remove anything older than 30 days
    };

    # Optimize the Nix store by hard-linking identical files.
    # Saves disk space with no downside.
    optimise.automatic = true;
  };

  # =========================================================================
  # FONTS
  #
  # Full Nerd Fonts collection — every patched font family in one go.
  # builtins.attrValues converts the nerd-fonts attrset into a list so
  # all families (JetBrainsMono, FiraCode, CascadiaCode, Hack, etc.) are
  # installed. nerd-fonts.symbols-only is the dedicated icon-only font
  # that acts as a system-wide fallback for Nerd Font glyph codepoints.
  #
  # noto-fonts-color-emoji is intentionally excluded — it would claim
  # the private-use-area codepoints that Nerd Fonts uses for icons,
  # causing fastfetch and terminal apps to render colored emoji boxes
  # instead of the actual icon glyphs.
  # =========================================================================
  fonts.packages = lib.filter lib.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  # =========================================================================
  # BASE PACKAGES
  #
  # Packages installed on every single machine — desktops, laptops, AND servers.
  # Keep this list to tools that are genuinely useful everywhere.
  # Desktop/graphical packages belong in modules/system/graphical.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Core utilities
    git          # Version control — needed for managing this config itself
    curl         # HTTP requests from the command line
    wget         # File downloads
    htop         # Interactive process viewer
    btop         # Modern resource monitor (prettier than htop)
    unzip        # Archive extraction
    tree         # Directory tree viewer
    jq           # JSON processor — used by Claude Code hooks and shell scripts

    # Network tools
    iproute2     # ip command for network management
    nmap         # Network scanner (useful for finding your machines on the network)
    dig          # DNS lookup tool
    rsync        # Fast file sync — local copies, remote backups, deploy scripts

    # Text editors (minimal, for emergency server access)
    nano         # Simple editor, always good to have available
    # Shell tools
    fastfetch    # System info display — useful on desktops AND servers via SSH

    # Node.js — needed for MCP servers (npx) and Claude Code hooks
    nodejs

    # Nix version diff — shows added/removed/updated packages between two
    # system closures. Used by _nixos_run to display what changed after rebuild.
    nvd
  ];

  # ===========================================================================
  # Environment variables for AI tools
  # ===========================================================================
  environment.sessionVariables = {
    # Enable Exa web search in OpenCode
    OPENCODE_ENABLE_EXA = "true";
  };

  # =========================================================================
  # POLKIT — allow wheel group to manage systemd units without interactive auth
  #
  # systemd 257+ requires polkit authorization for `systemd-run` transient
  # unit creation even when called as root. nixos-rebuild passes
  # --no-ask-password, which means polkit can't prompt — it just fails.
  # This rule grants the wheel group implicit YES for systemd unit management
  # so nixos-rebuild switch works without requiring a polkit agent session.
  #
  # Also covers login1 inhibit actions so systemd-inhibit (used by nru/nrb
  # to hold a sleep lock during rebuilds) doesn't prompt for a password.
  # =========================================================================
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id.indexOf("org.freedesktop.systemd1.") === 0 ||
           action.id.indexOf("org.freedesktop.login1.inhibit-") === 0) &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
    // Allow the fwupd-refresh system user to refresh LVFS metadata without
    // an interactive polkit session. The NixOS fwupd module omits this rule,
    // causing fwupd-refresh.service to always fail with "Failed to obtain auth".
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.fwupd.refresh-remote" &&
          subject.user == "fwupd-refresh") {
        return polkit.Result.YES;
      }
    });
  '';

  # =========================================================================
  # KERNEL SYSCTL TWEAKS
  #
  # fs.inotify.max_user_watches — how many filesystem watchers the kernel
  # allows per user. VSCode, the Claude Code extension, and Obsidian all
  # register watches for every file in open folders. With large repos +
  # the vault open simultaneously, 524288 (the NixOS default) gets exhausted.
  # 1048576 (1M) gives comfortable headroom. mkDefault so server host configs
  # can keep their explicit lower values if needed.
  # =========================================================================
  boot.kernel.sysctl."fs.inotify.max_user_watches" = lib.mkForce 1048576;

  # =========================================================================
  # BLUETOOTH
  #
  # Enabled system-wide — desktops, laptops, and servers that have a BT
  # adapter. powerOnBoot = false leaves the adapter off until the user
  # turns it on, avoiding unnecessary radio activity at startup.
  # btusb loaded at boot so /sys/class/bluetooth exists before bluetoothd
  # evaluates its ConditionPathIsDirectory check.
  #
  # blueman: provides the Bluetooth management GUI and D-Bus activation.
  # The blueman package ships /etc/xdg/autostart/blueman.desktop which would
  # auto-start the tray applet in every graphical session. We suppress it
  # system-wide via environment.etc — /etc/xdg is first in XDG_CONFIG_DIRS
  # so this Hidden=true file shadows the package's copy in
  # /run/current-system/sw/etc/xdg/autostart/. Each DE provides its own BT
  # management UI (COSMIC panel, KDE system tray, Noctalia bar widget);
  # no secondary tray icon is needed. blueman-manager is still launchable
  # manually when pairing new devices.
  # =========================================================================
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = lib.mkDefault false;
  services.blueman.enable = true;
  environment.etc."xdg/autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  boot.kernelModules = lib.mkAfter [ "btusb" ];

  # =========================================================================
  # FWUPD — firmware update daemon
  #
  # Lets you update firmware (BIOS, SSD, peripherals) via LVFS directly
  # from the command line or a GUI (e.g. GNOME Software / KDE Discover).
  # Run: fwupdmgr refresh && fwupdmgr update
  # =========================================================================
  services.fwupd.enable = true;

  # =========================================================================
  # TAILSCALE — mesh VPN
  #
  # Runs on every machine so you can reach all of them (desktops, laptops,
  # servers) from anywhere without port-forwarding or opening firewall ports.
  # After first boot on each machine: sudo tailscale up
  # =========================================================================
  services.tailscale.enable = true;

  # =========================================================================
  # SYSTEM STATE VERSION
  #
  # This tells NixOS which version's defaults to use for stateful data.
  # Set it to the NixOS version you first installed with and NEVER change it.
  # Changing it does NOT upgrade your system — it can break things.
  # =========================================================================
  system.stateVersion = "24.11";
}
