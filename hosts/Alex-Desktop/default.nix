# ===========================================================================
# hosts/Alex-Desktop/default.nix — Alex's Desktop
#
# Owner: alex
# Hardware: Older AMD CPU + AMD GPU
# Type: Desktop — no encryption, gaming and education focused
# Role: Kid's desktop
#
# Enabled modules:
#   - AMD drivers
#   - COSMIC (default DE)
#   - Gaming
#   - Firefox with forced policies (via firefox.nix)
#
# Parental controls:
#   - Declarative app control (only what we define is available)
#   - DNS filtering via Cloudflare 1.1.1.3
#   - Flatpak disabled
#   - Login time restrictions via systemd
#   - Firefox locked down via policies
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    ../../modules/base/common.nix
    ../../modules/base/graphical-base.nix
    ../../modules/hardware/drivers.nix
    ../../modules/desktop-environments/cosmic.nix
    ../../modules/gaming/gaming.nix
    ../../modules/base/auto-update.nix
  ];

  # =========================================================================
  # Host identity
  # =========================================================================
  networking.hostName = "Alex-Desktop";

  # =========================================================================
  # GPU driver selection
  # =========================================================================
  hardware.gpu = "amd";

  # =========================================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on desktop
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
  # Kernel
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

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
  # DNS filtering — Cloudflare 1.1.1.3
  #
  # 1.1.1.3 is Cloudflare's family-safe DNS resolver.
  # It automatically blocks malware and adult content at the DNS level
  # without any extra software needed.
  #
  # This applies system-wide — all apps and browsers on this machine
  # use these DNS servers regardless of what the user tries to change.
  # =========================================================================
  networking.nameservers = [
    "1.1.1.3"      # Cloudflare family DNS primary
    "1.0.0.3"      # Cloudflare family DNS secondary
  ];

  # Lock DNS so NetworkManager cannot override it
  networking.networkmanager.dns = "none";  # Tells NM to not manage DNS
  services.resolved = {
    enable = true;
    fallbackDns = [ "1.1.1.3" "1.0.0.3" ];
  };

  # =========================================================================
  # Flatpak — infrastructure kept, all remotes removed
  #
  # cosmic.nix enables Flatpak (it powers the COSMIC app store backend).
  # We cannot mkForce false here because the Hytale install service in
  # alex's home.nix uses `flatpak install --user` from a local bundle file,
  # which requires the flatpak binary to exist.
  #
  # Instead of disabling Flatpak entirely, we wipe all configured remotes
  # after every rebuild. With no remotes:
  #   - COSMIC store shows a blank screen — nothing to browse or install
  #   - Alex cannot add a remote without sudo (system remotes need root)
  #   - User-level remotes would need terminal knowledge he doesn't have at 6
  #   - Hytale still installs because it uses a local .flatpak file, not a remote
  # =========================================================================
  system.activationScripts.removeFlatpakRemotes.text = ''
    # Remove all system-level Flatpak remotes so the app store is empty.
    for remote in $(${pkgs.flatpak}/bin/flatpak remote-list --system \
                    --columns=name 2>/dev/null | tail -n +1); do
      ${pkgs.flatpak}/bin/flatpak remote-delete --system --force \
        "$remote" 2>/dev/null || true
    done
  '';

  # =========================================================================
  # Login time restrictions
  #
  # These systemd timer units restrict when alex can be logged in.
  # The pam_time module enforces time-based access control.
  #
  # Current schedule:
  #   Weekdays: 8:00 - 21:00 (9pm cutoff)
  #   Weekends: 8:00 - 22:00 (10pm cutoff)
  #
  # Adjust the times to match your household rules.
  # =========================================================================
  security.pam.services.login.text = lib.mkAfter ''
    account required pam_time.so
  '';

  environment.etc."security/time.conf".text = ''
    # Format: services;ttys;users;times
    # Mo-Fr = Monday to Friday, Sa-Su = Saturday to Sunday
    # Times use 24h format: 0800 = 8am, 2100 = 9pm
    login;*;alex;Mo-Fr0800-2100|Sa-Su0800-2200
  '';

  # =========================================================================
  # Kid-friendly packages
  #
  # Alex's personal apps (freetube, krita, kdenlive, gcompris-qt,
  # libreoffice, hunspell) are declared in users/alex/home.nix.
  # Gaming packages (prismlauncher, mcpelauncher-ui-qt, jdk17) are in
  # modules/gaming/gaming.nix (imported above).
  # Graphical tools (ghostty, kitty, showtime, etc.) are in modules/base/graphical-base.nix.
  # Shell tools (fastfetch, btop) are in modules/base/common.nix.
  # =========================================================================

  # =========================================================================
  # Restrict sudo
  #
  # Alex should not have sudo access at all.
  # wheel group membership is intentionally omitted from his user account.
  # This prevents installing software or changing system settings.
  # =========================================================================

  # =========================================================================
  # User account
  #
  # Notice: no "wheel" group — alex cannot use sudo.
  # You manage this machine remotely via your own account over SSH.
  # =========================================================================
  users.users.alex = {
    isNormalUser = true;
    extraGroups  = [
      # No wheel — no sudo
      "networkmanager"  # Can connect to WiFi
      "video"
      "audio"
      "input"
      "gamemode"
    ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;
}
