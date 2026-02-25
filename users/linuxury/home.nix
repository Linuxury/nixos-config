# ===========================================================================
# users/linuxury/home.nix — Home Manager config for linuxury
#
# Machines: ThinkPad (laptop), Ryzen5900x (desktop)
# Role: Admin, developer, power user
#
# This file is a function that accepts wallpaperDir from the flake.
# wallpaperDir is passed per-host in flake.nix:
#   ThinkPad   → "4k"
#   Ryzen5900x → "3440x1440"
#
# The wallpaperDir value gets symlinked:
#   ~/assets/Wallpapers/<wallpaperDir> → ~/Pictures/Wallpapers
#
# The wallpaper slideshow + matugen theming is handled by:
#   modules/services/wallpaper-slideshow.nix
# ===========================================================================

# Outer function — receives host-specific arguments from flake.nix
{ wallpaperDir, ... }:

# Inner function — receives Home Manager's standard arguments
{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    # Wallpaper slideshow + matugen theming
    # Rotates wallpapers every 30 minutes and syncs colors via matugen
    ../../modules/services/wallpaper-slideshow.nix
  ];

  # =========================================================================
  # Home Manager basics
  # =========================================================================
  home.username      = "linuxury";
  home.homeDirectory = "/home/linuxury";
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
    # Development workspace
    "d ${config.home.homeDirectory}/Projects              0755 linuxury users -"
    "d ${config.home.homeDirectory}/Projects/Python       0755 linuxury users -"
    "d ${config.home.homeDirectory}/Projects/Rust         0755 linuxury users -"
    "d ${config.home.homeDirectory}/Projects/Nix          0755 linuxury users -"
    "d ${config.home.homeDirectory}/Projects/Scripts      0755 linuxury users -"

    # Assets — wallpapers, avatars, game assets etc
    # Contents cloned separately — see docs/manual-steps.md
    "d ${config.home.homeDirectory}/assets                         0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/Avatar                  0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/Minecraft               0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/SteamGridDB             0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/Wallpapers              0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/Wallpapers/4k           0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/Wallpapers/3440x1440    0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/Wallpapers/PikaOS       0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/flatpaks                0755 linuxury users -"

    # SSH directory with correct permissions
    "d ${config.home.homeDirectory}/.ssh  0700 linuxury users -"
  ];

  # =========================================================================
  # Dotfiles — symlinked from dotfiles/ in your repo
  # =========================================================================
  home.file = {
    # Fish shell
    ".config/fish/config.fish".source = ../../dotfiles/fish/config.fish;

    # Starship prompt
    ".config/starship.toml".source = ../../dotfiles/starship/starship.toml;

    # Ghostty — config + cursor trail shaders
    ".config/ghostty/config".source  = ../../dotfiles/ghostty/config;
    ".config/ghostty/shader".source  = ../../dotfiles/ghostty/shader;

    # Helix editor
    ".config/helix".source = ../../dotfiles/helix;

    # Fastfetch
    ".config/fastfetch".source = ../../dotfiles/fastfetch;

    # Topgrade — NixOS flake version
    ".config/topgrade.toml".source = ../../dotfiles/topgrade/topgrade-nixos.toml;

    # MangoHud — performance overlay for gaming
    ".config/MangoHud".source = ../../dotfiles/MangoHud;

    # Nano — for quick root edits
    ".nanorc".source = ../../dotfiles/nano/.nanorc;

    # -----------------------------------------------------------------------
    # Wallpaper symlink
    #
    # ~/Pictures/Wallpapers → ~/assets/Wallpapers/<wallpaperDir>
    #
    # wallpaperDir is passed per-host from flake.nix:
    #   ThinkPad   → "4k"
    #   Ryzen5900x → "3440x1440"
    #
    # The wallpaper slideshow script always reads from ~/Pictures/Wallpapers
    # so it works identically on both machines without any changes.
    #
    # mkOutOfStoreSymlink creates a symlink to a path outside the Nix store
    # (important since wallpapers are in ~/assets, not in the repo itself)
    # -----------------------------------------------------------------------
    "Pictures/Wallpapers".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/assets/Wallpapers/${wallpaperDir}";

    # SSH config — structure only, no keys
    ".ssh/config".text = ''
      # ===========================================================
      # SSH Config — linuxury
      # Keys are managed manually, not stored in the repo.
      # After first boot:
      #   ssh-keygen -t ed25519 -C "linuxury"
      #   ssh-copy-id -i ~/.ssh/id_ed25519 user@host
      # ===========================================================

      Host *
        AddKeysToAgent      yes
        IdentitiesOnly      yes
        ServerAliveInterval 60
        ServerAliveCountMax 3

      Host github.com
        HostName     github.com
        User         git
        IdentityFile ~/.ssh/id_ed25519

      Host media-server
        HostName     Media-Server
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host minisforum
        HostName     MinisForum
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host radxa
        HostName     Radxa-X4
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host ryzen5800x
        HostName     Ryzen5800x
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host asus-a15
        HostName     Asus-A15
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519
    '';
  };

  # =========================================================================
  # Fish shell
  # =========================================================================
  programs.fish = {
    enable = true;
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
    userName  = "Linuxury";
    userEmail = "linuxurypr@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase        = false;
      core.editor        = "hx";
      alias = {
        st  = "status";
        co  = "checkout";
        br  = "branch";
        lg  = "log --oneline --graph --decorate";
      };
    };
  };

  # =========================================================================
  # Helix editor
  # Config managed via home.file symlink from dotfiles/helix/
  # =========================================================================
  programs.helix = {
    enable = true;
  };

  # =========================================================================
  # VSCodium — GUI editor with Claude extension support
  # =========================================================================
  programs.vscode = {
    enable  = true;
    package = pkgs.vscodium;
    extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
      ms-python.python
      ms-python.black-formatter
      rust-lang.rust-analyzer
      eamodio.gitlens
      enkia.tokyo-night
      esbenp.prettier-vscode
      usernamehw.errorlens
      gruntfuggly.todo-tree
    ];
    userSettings = {
      "editor.fontFamily"                      = "JetBrainsMono Nerd Font";
      "editor.fontSize"                        = 14;
      "editor.fontLigatures"                   = true;
      "editor.lineHeight"                      = 1.6;
      "editor.tabSize"                         = 2;
      "editor.formatOnSave"                    = true;
      "editor.bracketPairColorization.enabled" = true;
      "editor.cursorBlinking"                  = "smooth";
      "editor.smoothScrolling"                 = true;
      "workbench.colorTheme"                   = "Tokyo Night";
      "workbench.list.smoothScrolling"         = true;
      "terminal.integrated.fontFamily"         = "JetBrainsMono Nerd Font";
      "files.autoSave"                         = "afterDelay";
      "nix.enableLanguageServer"               = true;
      "nix.serverPath"                         = "nil";
    };
  };

  # =========================================================================
  # Zoxide — smarter cd
  # =========================================================================
  programs.zoxide = {
    enable                = true;
    enableFishIntegration = true;
  };

  # =========================================================================
  # FZF — fuzzy finder
  # =========================================================================
  programs.fzf = {
    enable                = true;
    enableFishIntegration = true;
  };

  # =========================================================================
  # Direnv — per-project environments
  # =========================================================================
  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
  };

  # =========================================================================
  # Tailscale
  # After first boot: sudo tailscale up
  # =========================================================================
  services.tailscale.enable = true;

  # =========================================================================
  # SSH agent
  # =========================================================================
  services.ssh-agent.enable = true;

  # =========================================================================
  # Dunst — notification daemon for WM sessions
  # Inactive in COSMIC — DE handles notifications natively
  # Will activate automatically when Hyprland/Niri are enabled
  # =========================================================================
  services.dunst = {
    enable = true;
  };

  # =========================================================================
  # Personal packages
  # =========================================================================
  home.packages = with pkgs; [

    # Terminals
    ghostty
    kitty

    # Shell tools
    fastfetch
    topgrade

    # File management
    yazi
    eza
    bat

    # Development helpers
    lazygit
    gh
    delta

    # System monitoring
    btop
    dust
    procs

    # Gaming — Minecraft
    prismlauncher
    mcpelauncher-ui-qt
    jdk17
    jdk8

    # Productivity
    obsidian

    # Media
    mpv
    imv

    # Networking
    tailscale
    whois
    traceroute

    # Misc utilities
    wl-clipboard
    xdg-utils
    p7zip
    imagemagick
  ];
}
