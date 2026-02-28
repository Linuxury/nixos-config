# ===========================================================================
# users/alex/home.nix — Home Manager config for alex
#
# Machines: Alex-Desktop, Alex-Laptop
# Age: 6 years old
# Role: Kids machine — educational, creative, gaming
#
# This file is a function that accepts wallpaperDir from the flake.
# wallpaperDir is passed per-host in flake.nix:
#   Alex-Desktop → "PikaOS"
#   Alex-Laptop  → "PikaOS"
#
# Notable:
#   - No sudo access (enforced at host level)
#   - DNS filtering via Cloudflare 1.1.1.3 (host level)
#   - Login time restrictions (host level)
#   - Flatpak disabled system-wide except for Hytale (host level)
#   - Terminal included — he'll grow into it
#   - Own Mojang account for Minecraft
#   - Hytale from bundled flatpak in assets repo
#   - PikaOS wallpapers generate kid-friendly color schemes via matugen
# ===========================================================================

# Single function — wallpaperDir comes from extraSpecialArgs in flake.nix
{ config, pkgs, inputs, lib, wallpaperDir, ... }:

{
  imports = [
    # Wallpaper slideshow + matugen theming
    # PikaOS wallpapers will generate colorful kid-friendly themes
    ../../modules/services/wallpaper-slideshow.nix
  ];

  # =========================================================================
  # Home Manager basics
  # =========================================================================
  home.username      = "alex";
  home.homeDirectory = "/home/alex";
  home.stateVersion  = "24.11";

  programs.home-manager.enable = true;

  # =========================================================================
  # XDG User Directories
  # =========================================================================
  xdg.userDirs = {
    enable            = true;
    createDirectories = true;

    desktop    = "${config.home.homeDirectory}/Desktop";
    documents  = "${config.home.homeDirectory}/Documents";
    download   = "${config.home.homeDirectory}/Downloads";
    music      = "${config.home.homeDirectory}/Music";
    pictures   = "${config.home.homeDirectory}/Pictures";
    videos     = "${config.home.homeDirectory}/Videos";
    templates  = "${config.home.homeDirectory}/Templates";
    publicShare = "${config.home.homeDirectory}/Public";
  };

  # =========================================================================
  # Extra directories
  # =========================================================================
  systemd.user.tmpfiles.rules = [
    # Assets — kid friendly wallpapers
    # Contents cloned separately — see docs/manual-steps.md
    "d ${config.home.homeDirectory}/assets                        0755 alex users -"
    "d ${config.home.homeDirectory}/assets/Wallpapers             0755 alex users -"
    "d ${config.home.homeDirectory}/assets/Wallpapers/PikaOS      0755 alex users -"
    "d ${config.home.homeDirectory}/assets/Minecraft              0755 alex users -"
    "d ${config.home.homeDirectory}/assets/flatpaks               0755 alex users -"

    # Creative workspace
    "d ${config.home.homeDirectory}/Documents/Art                 0755 alex users -"
    "d ${config.home.homeDirectory}/Documents/Videos              0755 alex users -"
    "d ${config.home.homeDirectory}/Documents/School              0755 alex users -"
  ];

  # =========================================================================
  # Dotfiles — shared terminal setup with the rest of the family
  # =========================================================================
  home.file = {
    # Starship prompt — shared config
    ".config/starship.toml".source = ../../dotfiles/starship/starship.toml;

    # Ghostty — shared config
    ".config/ghostty/config".source = ../../dotfiles/ghostty/config;

    # Fastfetch — shared config
    ".config/fastfetch".source = ../../dotfiles/fastfetch;

    # -----------------------------------------------------------------------
    # Wallpaper symlink
    #
    # ~/Pictures/Wallpapers → ~/assets/Wallpapers/PikaOS
    # Both his machines use "PikaOS" — set in flake.nix
    # matugen generates colorful kid-friendly themes from these wallpapers
    # -----------------------------------------------------------------------
    "Pictures/Wallpapers".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/assets/Wallpapers/${wallpaperDir}";
  };

  # =========================================================================
  # Fish shell
  # =========================================================================
  programs.fish = {
    enable    = true;
    shellInit = lib.fileContents ../../dotfiles/fish/config.fish;
  };

  # =========================================================================
  # Starship prompt
  # =========================================================================
  programs.starship = {
    enable = true;
  };

  # =========================================================================
  # Hytale — automatic flatpak installation from bundled file
  #
  # Same approach as babylinux — installs from assets repo on first login.
  #
  # Note: Flatpak is disabled system-wide on Alex's machines via
  # lib.mkForce false in the host config to prevent him installing
  # random apps. We re-enable it specifically for Hytale only.
  # This exception is handled in hosts/Alex-Desktop and hosts/Alex-Laptop.
  #
  # Notification messages use plain language — he's 6.
  # =========================================================================
  systemd.user.services.hytale-flatpak-install = {
    Unit = {
      Description         = "Install Hytale launcher from bundled flatpak";
      After               = [ "graphical-session.target" ];
      Wants               = [ "graphical-session.target" ];
      ConditionPathExists = "!%h/.local/share/flatpak/app/com.hytale.Hytale";
    };

    Service = {
      Type      = "oneshot";
      Restart   = "no";
      ExecStart = "${pkgs.writeShellScript "install-hytale-alex" ''
        FLATPAK="${pkgs.flatpak}/bin/flatpak"
        NOTIFY="${pkgs.libnotify}/bin/notify-send"
        FLATPAK_FILE="$HOME/assets/flatpaks/hytale-launcher-latest.flatpak"

        if $FLATPAK info --user com.hytale.Hytale &>/dev/null; then
          echo "Hytale already installed, skipping."
          exit 0
        fi

        if [ ! -f "$FLATPAK_FILE" ]; then
          echo "Hytale flatpak not found at $FLATPAK_FILE"
          $NOTIFY \
            --app-name "Hytale" \
            --icon "dialog-warning" \
            --urgency normal \
            "Hytale Not Installed" \
            "Ask your dad to set up the assets folder first."
          exit 1
        fi

        $NOTIFY \
          --app-name "Hytale" \
          --icon "system-software-install" \
          --urgency normal \
          "Installing Hytale" \
          "Installing Hytale launcher, almost ready to play!"

        if $FLATPAK install --user --noninteractive "$FLATPAK_FILE"; then
          $NOTIFY \
            --app-name "Hytale" \
            --icon "system-software-install" \
            --urgency normal \
            "Hytale Ready!" \
            "Hytale launcher is installed and ready to play!"
        else
          $NOTIFY \
            --app-name "Hytale" \
            --icon "dialog-error" \
            --urgency critical \
            "Hytale Install Failed" \
            "Something went wrong. Ask your dad for help."
        fi
      ''}";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # =========================================================================
  # SSH agent — included for consistency
  # Alex won't use SSH now but harmless to include
  # =========================================================================
  services.ssh-agent.enable = true;

  # =========================================================================
  # Personal packages
  #
  # Packages already provided elsewhere — do not re-add:
  #   common.nix         → fastfetch
  #   graphical-base.nix → ghostty, kitty, mpv, imv, wl-clipboard, xdg-utils
  #   gaming.nix         → prismlauncher, mcpelauncher-ui-qt, jdk17
  # =========================================================================
  home.packages = with pkgs; [

    # -----------------------------------------------------------------------
    # Educational
    # -----------------------------------------------------------------------
    gcompris-qt     # 100+ educational activities — ages 2-10
                    # Math, reading, geography, science, typing

    # -----------------------------------------------------------------------
    # Creative
    # -----------------------------------------------------------------------
    krita           # Digital painting and drawing
    kdenlive        # Video editor — simple enough for kids

    # -----------------------------------------------------------------------
    # Office / School
    # -----------------------------------------------------------------------
    libreoffice         # Full office suite — Writer, Impress, Calc
    hunspell            # Spell checker for LibreOffice
    hunspellDicts.en-us # English (US) dictionary

    # -----------------------------------------------------------------------
    # Media
    # -----------------------------------------------------------------------
    freetube        # YouTube without ads, algorithm, or shorts
  ];
}
