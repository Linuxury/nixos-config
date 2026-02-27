# ===========================================================================
# modules/base/common.nix — Shared base configuration for ALL hosts
#
# Every single machine in your setup (desktops, laptops, servers) imports
# this file. Think of it as the foundation everything else builds on top of.
#
# Rule of thumb: if every machine needs it, it lives here.
# If only some machines need it, it belongs in a more specific module.
# ===========================================================================

{ config, pkgs, inputs, ... }:

{
  imports = [
    # Automatic BTRFS snapshots + monthly scrub — runs on every host
    ./snapper.nix
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
    };

    # -----------------------------------------------------------------------
    # Plymouth — graphical boot splash
    # The theme can be overridden per host if you want different looks.
    # -----------------------------------------------------------------------
    plymouth = {
      enable = true;
      # "bgrt" shows the manufacturer logo from your UEFI firmware.
      # Other options: "spinner", "tribar", "fade-in", or install a custom theme.
      theme = "bgrt";
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
    networkmanager.enable = true;

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
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBw="
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85d/E="
      ];

      # Allow your user to manage the Nix store without sudo for some operations
      trusted-users = [ "root" "@wheel" ];
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
  # nerd-fonts.jetbrains-mono includes all three variants:
  #   JetBrainsMono Nerd Font        — monospaced (terminal default)
  #   JetBrainsMono Nerd Font Mono   — monospaced, smaller icons
  #   JetBrainsMono Nerd Font Propo  — proportional spacing (UI text)
  #
  # noto-fonts-color-emoji fills in any emoji glyphs your terminal font doesn't
  # cover — required for full emoji support in terminals and apps.
  # =========================================================================
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
  ];

  # =========================================================================
  # BASE PACKAGES
  #
  # Packages installed on every single machine — desktops, laptops, servers.
  # Keep this list to tools that are genuinely useful everywhere.
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

    # Network tools
    iproute2     # ip command for network management
    nmap         # Network scanner (useful for finding your machines on the network)
    dig          # DNS lookup tool

    # Text editors (minimal, for emergency server access)
    nano         # Simple editor, always good to have available
    vim          # For those who prefer it

    # -----------------------------------------------------------------------
    # Shared desktop/family packages
    #
    # Present on all machines including servers — harmless on headless hosts,
    # and tools like fastfetch are useful even over SSH.
    # -----------------------------------------------------------------------

    # Terminals
    ghostty      # Fast GPU-accelerated terminal
    kitty        # Alternative GPU-accelerated terminal

    # Shell tools
    fastfetch    # System info display — useful on desktops and over SSH

    # Media
    mpv          # Lightweight video player — plays almost anything
    imv          # Wayland image viewer

    # Wayland / desktop utilities
    wl-clipboard # wl-copy / wl-paste — Wayland clipboard in scripts
    xdg-utils    # xdg-open — opens files with the correct app
  ];

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
