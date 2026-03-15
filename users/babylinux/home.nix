# ===========================================================================
# users/babylinux/home.nix — Home Manager config for babylinux
#
# Machines: Ryzen5800x (desktop), Asus-A15 (laptop)
# Role: Daily driver — light gaming, media, office
#
# This file is a function that accepts wallpaperDir from the flake.
# wallpaperDir is passed per-host in flake.nix:
#   Ryzen5800x → "4k"
#   Asus-A15   → "4k"
#
# Notable:
#   - Hytale installed from bundled flatpak in assets repo
#   - Prism Launcher for Minecraft (Java Edition)
#   - Shares terminal dotfiles with linuxury (ghostty + kitty)
# ===========================================================================

# Single function — wallpaperDir comes from extraSpecialArgs in flake.nix
{ config, pkgs, inputs, lib, wallpaperDir, ... }:

{
  imports = [];

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
  # G4Music's desktop entry ID: com.github.neithern.g4music.desktop
  # =========================================================================
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "audio/mpeg"       = "com.github.neithern.g4music.desktop";  # MP3
      "audio/ogg"        = "com.github.neithern.g4music.desktop";  # OGG Vorbis
      "audio/flac"       = "com.github.neithern.g4music.desktop";  # FLAC
      "audio/x-flac"     = "com.github.neithern.g4music.desktop";
      "audio/wav"        = "com.github.neithern.g4music.desktop";  # WAV
      "audio/x-wav"      = "com.github.neithern.g4music.desktop";
      "audio/mp4"        = "com.github.neithern.g4music.desktop";  # M4A / AAC
      "audio/aac"        = "com.github.neithern.g4music.desktop";
      "audio/x-m4a"      = "com.github.neithern.g4music.desktop";
      "audio/opus"       = "com.github.neithern.g4music.desktop";  # Opus
      "audio/webm"       = "com.github.neithern.g4music.desktop";
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

    # ~/Pictures/Fastfetch → nixos-config/assets/Fastfetch (fastfetch logo images)
    "Pictures/Fastfetch".source =
      config.lib.file.mkOutOfStoreSymlink
        "/home/linuxury/nixos-config/assets/Fastfetch";

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
        SetEnv              TERM=xterm-256color

      Host media-server
        HostName     Media-Server
        User         babylinux
        IdentityFile ~/.ssh/id_ed25519
    '';
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

    zsh-abbr = {
      enable = true;
      abbreviations = {
        nr    = "sudo systemd-inhibit --what=sleep:idle --who=nixos-rebuild --why=\"NixOS rebuild in progress\" nixos-rebuild switch --flake ~/nixos-config --print-build-logs";
        nrb   = "sudo nixos-rebuild boot --flake ~/nixos-config --print-build-logs";
        nrt   = "sudo nixos-rebuild test --flake ~/nixos-config --print-build-logs";
        nrr   = "sudo nixos-rebuild switch --rollback";
        ngc   = "sudo nix-collect-garbage --delete-older-than 30d";
        ngens = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
        age-edit  = "env -C ~/nixos-config/secrets nix run github:ryantm/agenix -- -e";
        age-rekey = "env -C ~/nixos-config/secrets nix run github:ryantm/agenix -- -r";
      };
    };

    shellAliases = {
      ll = "eza -la --color=always --icons --group-directories-first --git";
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
  # Zoxide — smarter cd
  # =========================================================================
  programs.zoxide = {
    enable               = true;
    enableZshIntegration = true;
  };

  # =========================================================================
  # FZF — fuzzy finder
  # =========================================================================
  programs.fzf = {
    enable               = true;
    enableZshIntegration = true;
  };

  # =========================================================================
  # Direnv — auto-loads .envrc on cd (nix develop shells, project env vars)
  # =========================================================================
  programs.direnv = {
    enable               = true;
    enableZshIntegration = true;
    nix-direnv.enable    = true;
  };

  # =========================================================================
  # Git
  # =========================================================================
  programs.git = {
    enable    = true;
    settings = {
      user.name  = "babylinux";
      user.email = "her@email.com"; # Replace with her actual email
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
      ]
    '';
  };

  # Personal packages live in modules/users/babylinux-packages.nix
}
