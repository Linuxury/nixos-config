# ===========================================================================
# users/babylinux/home.nix — Home Manager config for babylinux
#
# Machines: Ryzen5800x (desktop), Asus-A15 (laptop)
# Role: Daily driver — light gaming, media, office, torrenting
#
# This file is a function that accepts wallpaperDir from the flake.
# wallpaperDir is passed per-host in flake.nix:
#   Ryzen5800x → "4k"
#   Asus-A15   → "4k"
#
# Notable:
#   - qBittorrent runs inside a WireGuard network namespace
#     (VPN Unlimited via wg-quick) — killswitch scoped to qBittorrent only
#   - Hytale installed from bundled flatpak in assets repo
#   - Prism Launcher + Bedrock launcher for Minecraft
#   - Shares terminal dotfiles with linuxury (ghostty + kitty)
# ===========================================================================

# Single function — wallpaperDir comes from extraSpecialArgs in flake.nix
{ config, pkgs, inputs, lib, wallpaperDir, ... }:

{
  imports = [
    # Wallpaper slideshow + matugen theming
    ../../modules/services/wallpaper-slideshow.nix
  ];

  # =========================================================================
  # Home Manager basics
  # =========================================================================
  home.username      = "babylinux";
  home.homeDirectory = "/home/babylinux";
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
    # Wallpaper source — wallpapers are stored locally per user (not in the repo)
    # ~/Pictures/Wallpapers symlinks here (see home.file below)
    "d ${config.home.homeDirectory}/assets                        0755 babylinux users -"
    "d ${config.home.homeDirectory}/assets/Wallpapers             0755 babylinux users -"
    "d ${config.home.homeDirectory}/assets/Wallpapers/4k          0755 babylinux users -"

    # Profile photos live in ~/Pictures/Avatar (plain dir, add photos manually)
    "d ${config.home.homeDirectory}/Pictures/Avatar               0755 babylinux users -"

    # Hytale flatpak bundle storage — moved to ~/Documents/assets/flatpaks
    "d ${config.home.homeDirectory}/Documents/assets              0755 babylinux users -"
    "d ${config.home.homeDirectory}/Documents/assets/flatpaks     0755 babylinux users -"

    # SSH directory with correct permissions
    "d ${config.home.homeDirectory}/.ssh  0700 babylinux users -"

    # qBittorrent download staging
    "d ${config.home.homeDirectory}/Downloads/torrents            0755 babylinux users -"
    "d ${config.home.homeDirectory}/Downloads/torrents/complete   0755 babylinux users -"
    "d ${config.home.homeDirectory}/Downloads/torrents/incomplete 0755 babylinux users -"
  ];

  # =========================================================================
  # Dotfiles — shared terminal setup with linuxury
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
    # ~/Pictures/Wallpapers → ~/assets/Wallpapers/<wallpaperDir>
    # Both her machines use "4k" — set in flake.nix
    # -----------------------------------------------------------------------
    "Pictures/Wallpapers".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/assets/Wallpapers/${wallpaperDir}";

    # SSH config
    ".ssh/config".text = ''
      # ===========================================================
      # SSH Config — babylinux
      # Keys are managed manually, not stored in the repo.
      # After first boot add your keys to ~/.ssh/
      # ===========================================================

      Host *
        AddKeysToAgent      yes
        IdentitiesOnly      yes
        ServerAliveInterval 60
        ServerAliveCountMax 3

      Host media-server
        HostName     Media-Server
        User         babylinux
        IdentityFile ~/.ssh/id_ed25519
    '';
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
  # Git
  # =========================================================================
  programs.git = {
    enable    = true;
    userName  = "babylinux";
    userEmail = "her@email.com"; # Replace with her actual email
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase        = false;
    };
  };

  # =========================================================================
  # Hytale — automatic flatpak installation from bundled file
  #
  # Hytale is not on Flathub yet. We bundle the flatpak from the developer
  # directly in the assets repo and install it automatically on first login.
  #
  # Source: https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak
  # Store at: ~/assets/flatpaks/hytale-launcher-latest.flatpak
  #
  # When Hytale eventually lands on Flathub:
  #   1. Remove assets/flatpaks/hytale-launcher-latest.flatpak
  #   2. Replace this service with a proper flatpak declaration
  #   3. Rebuild
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
      ExecStart = "${pkgs.writeShellScript "install-hytale" ''
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
  # SSH agent
  # =========================================================================
  services.ssh-agent.enable = true;

  # =========================================================================
  # Personal packages
  # =========================================================================
  # Personal packages
  #
  # Packages already provided elsewhere — do not re-add:
  #   common.nix         → fastfetch
  #   graphical-base.nix → ghostty, kitty, mpv, imv, wl-clipboard, xdg-utils
  #   gaming.nix         → prismlauncher, mcpelauncher-ui-qt, jdk17
  # =========================================================================
  home.packages = with pkgs; [

    # Office
    onlyoffice-desktopeditors  # Word/Excel/PowerPoint compatible office suite

    # Communication
    zoom-us         # Video conferencing
  ];
}
