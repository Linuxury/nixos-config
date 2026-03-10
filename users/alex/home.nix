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
  # XDG MIME type associations
  #
  # Tells the desktop environment which app opens each file type.
  # Amberol's desktop entry ID: io.bassi.Amberol.desktop
  # =========================================================================
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "audio/mpeg"       = "io.bassi.Amberol.desktop";  # MP3
      "audio/ogg"        = "io.bassi.Amberol.desktop";  # OGG Vorbis
      "audio/flac"       = "io.bassi.Amberol.desktop";  # FLAC
      "audio/x-flac"     = "io.bassi.Amberol.desktop";
      "audio/wav"        = "io.bassi.Amberol.desktop";  # WAV
      "audio/x-wav"      = "io.bassi.Amberol.desktop";
      "audio/mp4"        = "io.bassi.Amberol.desktop";  # M4A / AAC
      "audio/aac"        = "io.bassi.Amberol.desktop";
      "audio/x-m4a"      = "io.bassi.Amberol.desktop";
      "audio/opus"       = "io.bassi.Amberol.desktop";  # Opus
      "audio/webm"       = "io.bassi.Amberol.desktop";
    };
  };

  xdg.configFile."mimeapps.list".force = true;

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
    # Wallpaper source — wallpapers stored locally (not in repo)
    # ~/Pictures/Wallpapers symlinks here (see home.file below)
    "d ${config.home.homeDirectory}/assets                        0755 alex users -"
    "d ${config.home.homeDirectory}/assets/Wallpapers             0755 alex users -"
    "d ${config.home.homeDirectory}/assets/Wallpapers/PikaOS      0755 alex users -"

    # Minecraft assets (skins, resource packs) — game-specific, kept in ~/assets
    "d ${config.home.homeDirectory}/assets/Minecraft              0755 alex users -"

    # Hytale flatpak bundle storage — moved to ~/Documents/assets/flatpaks
    "d ${config.home.homeDirectory}/Documents/assets              0755 alex users -"
    "d ${config.home.homeDirectory}/Documents/assets/flatpaks     0755 alex users -"

    # Creative workspace
    "d ${config.home.homeDirectory}/Documents/Art                 0755 alex users -"
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
  # Zsh shell
  # =========================================================================
  programs.zsh = {
    enable            = true;
    autosuggestion.enable = true;
    enableCompletion  = true;

    plugins = [
      {
        name = "fast-syntax-highlighting";
        src  = pkgs.zsh-fast-syntax-highlighting;
        file = "share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh";
      }
    ];

    # Minimal abbreviations for alex — he won't use most of these but they're
    # harmless, and he'll grow into them.
    zsh-abbr = {
      enable = true;
      abbreviations = {
        nr    = "sudo systemd-inhibit --what=sleep:idle --who=nixos-rebuild --why=\"NixOS rebuild in progress\" nixos-rebuild switch --flake ~/nixos-config --print-build-logs";
        nrb   = "sudo nixos-rebuild boot --flake ~/nixos-config --print-build-logs";
        nrt   = "sudo nixos-rebuild test --flake ~/nixos-config --print-build-logs";
        nrr   = "sudo nixos-rebuild switch --rollback";
        ngc   = "sudo nix-collect-garbage --delete-older-than 30d";
        ngens = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
      };
    };

    initContent = lib.fileContents ../../dotfiles/zsh/zshrc;
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
        FLATPAK_FILE="$HOME/Documents/assets/flatpaks/hytale-launcher-latest.flatpak"

        if $FLATPAK info --user com.hytale.Hytale &>/dev/null; then
          echo "Hytale already installed, skipping."
          exit 0
        fi

        if [ ! -f "$FLATPAK_FILE" ]; then
          echo "ERROR: Hytale flatpak not found at $FLATPAK_FILE"
          echo "  Place hytale-launcher-latest.flatpak in ~/Documents/assets/flatpaks/ and reboot."
          exit 1
        fi

        echo "Installing Hytale launcher..."
        if $FLATPAK install --user --noninteractive "$FLATPAK_FILE"; then
          echo "Hytale installed successfully."
        else
          echo "ERROR: Hytale install failed. Check journalctl --user -u hytale-flatpak-install"
          exit 1
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
  # COSMIC Files — sidebar favorites
  #
  # Path() display name = last path segment, so /mnt/Media-Server → "Media-Server".
  # Missing paths are silently skipped (safe on laptops not on home LAN).
  # =========================================================================
  home.file.".config/cosmic/com.system76.CosmicFiles/v1/favorites" = {
    force = true;
    text = ''
      [
          Home,
          Documents,
          Downloads,
          Music,
          Pictures,
          Videos,
          Path("/mnt/Media-Server"),
          Path("/mnt/MinisForum"),
          Path("/mnt/Torrents"),
      ]
    '';
  };

  # Personal packages live in modules/users/alex-packages.nix
}
