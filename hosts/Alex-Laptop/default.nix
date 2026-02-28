# ===========================================================================
# hosts/Alex-Laptop/default.nix — Alex's Laptop (HP with AMD A-10 APU)
#
# Owner: alex
# Hardware: Older HP laptop, AMD A-10 APU (integrated graphics)
# Type: Laptop — LUKS encrypted, kid focused
# Role: Kid's laptop — school, gaming, videos
#
# Enabled modules:
#   - AMD drivers
#   - COSMIC (default DE)
#   - Gaming
#   - Firefox with forced policies (via firefox.nix)
#
# Parental controls:
#   - Same as Alex-Desktop
#   - LUKS encryption since it's a laptop
#   - Extra power management for older battery
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
  networking.hostName = "Alex-Laptop";

  # =========================================================================
  # GPU driver selection
  #
  # AMD A-10 APU uses integrated Radeon graphics.
  # Same amdgpu driver as dedicated cards — works fine.
  # =========================================================================
  hardware.gpu = "amd";

  # =========================================================================
  # LUKS — Full disk encryption
  # Laptop can travel so we encrypt it just like the other laptops.
  # =========================================================================
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-label/nixos-luks";
    allowDiscards = true;
  };

  # Use spinner theme for the LUKS passphrase prompt — cleaner than bgrt
  boot.plymouth.theme = "spinner";

  # =========================================================================
  # Filesystem — BTRFS with subvolumes on top of LUKS
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
  #
  # Using latest stable rather than testing on this older hardware.
  # Older AMD APUs are very well supported and stable — no need
  # to risk RC kernel instability on a kid's school laptop.
  # =========================================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # =========================================================================
  # Performance tweaks for older hardware
  #
  # The A-10 APU is older and lower powered. These tweaks help it
  # run more smoothly with limited resources.
  # =========================================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
    "mitigations=auto"    # Keep security mitigations but let kernel
                          # choose the least impactful ones for this CPU
  ];

  # Limit Nix parallel builds so the system stays responsive
  # Old hardware struggles when Nix tries to build many things at once
  nix.settings.max-jobs = 2;

  # =========================================================================
  # Power management — important for older laptop battery
  #
  # Older batteries benefit even more from conservative power management.
  # =========================================================================
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC  = "ondemand";   # Balanced on AC
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";  # Aggressive saving on battery
      CPU_ENERGY_PERF_POLICY_ON_AC  = "balance-performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Conservative battery thresholds for older battery health
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0  = 80;

      PCIE_ASPM_ON_BAT = "powersupersave";

      # Aggressive disk power saving on battery
      DISK_APM_LEVEL_ON_BAT = "1";
    };
  };

  services.power-profiles-daemon.enable = false;

  # =========================================================================
  # Touchpad
  # =========================================================================
  services.libinput = {
    enable = true;
    touchpad = {
      tapping            = true;
      naturalScrolling   = true;
      scrollMethod       = "twofinger";
      middleEmulation    = true;
      disableWhileTyping = true;
    };
  };

  # =========================================================================
  # Lid and power button behavior
  # =========================================================================
  services.logind = {
    lidSwitch              = "suspend";
    lidSwitchExternalPower = "suspend";
    extraConfig = ''
      HandlePowerKey=suspend
      IdleAction=suspend
      IdleActionSec=15min
    '';
  };

  # =========================================================================
  # DNS filtering — same as Alex-Desktop
  # =========================================================================
  networking.nameservers = [ "1.1.1.3" "1.0.0.3" ];
  networking.networkmanager.dns = "none";
  services.resolved = {
    enable = true;
    fallbackDns = [ "1.1.1.3" "1.0.0.3" ];
  };

  # =========================================================================
  # Flatpak — infrastructure kept, all remotes removed
  # Same approach as Alex-Desktop — see comment there for full explanation.
  # =========================================================================
  system.activationScripts.removeFlatpakRemotes.text = ''
    for remote in $(${pkgs.flatpak}/bin/flatpak remote-list --system \
                    --columns=name 2>/dev/null | tail -n +1); do
      ${pkgs.flatpak}/bin/flatpak remote-delete --system --force \
        "$remote" 2>/dev/null || true
    done
  '';

  # =========================================================================
  # Login time restrictions — same schedule as desktop
  # =========================================================================
  security.pam.services.login.text = lib.mkAfter ''
    account required pam_time.so
  '';

  environment.etc."security/time.conf".text = ''
    login;*;alex;Mo-Fr0800-2100|Sa-Su0800-2200
  '';

  # =========================================================================
  # Packages
  #
  # Alex's personal apps (freetube, krita, kdenlive, gcompris-qt,
  # libreoffice, hunspell) are declared in users/alex/home.nix.
  # Gaming packages (prismlauncher, mcpelauncher-ui-qt, jdk17) are in
  # modules/gaming/gaming.nix (imported above).
  # Graphical tools (ghostty, kitty, showtime, etc.) are in modules/base/graphical-base.nix.
  # Shell tools (fastfetch, btop) are in modules/base/common.nix.
  # =========================================================================

  # =========================================================================
  # User account — no wheel, same restrictions as desktop
  # =========================================================================
  users.users.alex = {
    isNormalUser = true;
    extraGroups  = [
      "networkmanager"
      "video"
      "audio"
      "input"
      "gamemode"
    ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;
}
