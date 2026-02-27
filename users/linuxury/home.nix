# ===========================================================================
# users/linuxury/home.nix — Home Manager config for linuxury
#
# Machines: ThinkPad (laptop), Ryzen5900x (desktop)
# Role: Admin, developer, power user
#
# wallpaperDir is injected via extraSpecialArgs in flake.nix, per-host:
#   ThinkPad   → "4k"
#   Ryzen5900x → "3440x1440"
#
# The wallpaperDir value gets symlinked:
#   ~/nixos-config/assets/Wallpapers/<wallpaperDir> → ~/Pictures/Wallpapers
#
# The wallpaper slideshow + matugen theming is handled by:
#   modules/services/wallpaper-slideshow.nix
# ===========================================================================

# Single function — wallpaperDir comes from extraSpecialArgs in flake.nix
{ config, pkgs, inputs, lib, wallpaperDir, ... }:

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
  # Session PATH — expose Nix profile bin to GUI apps
  #
  # GUI apps launched from COSMIC run inside a systemd user session whose
  # PATH comes from environment.d configs, not from shell profiles.
  # Without this, apps like VSCodium can't find binaries installed via
  # Home Manager (e.g. claude-code, nil, nixfmt).
  #
  # home.sessionPath writes to ~/.config/environment.d/ which systemd user
  # sessions read automatically — no shell involved.
  # =========================================================================
  home.sessionPath = [
    "/etc/profiles/per-user/linuxury/bin"
    "/run/current-system/sw/bin"
  ];

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

    # Assets — avatars, game assets etc
    # Wallpapers live in the repo: ~/nixos-config/assets/Wallpapers/
    "d ${config.home.homeDirectory}/assets                         0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/Avatar                  0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/Minecraft               0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/SteamGridDB             0755 linuxury users -"
    "d ${config.home.homeDirectory}/assets/flatpaks                0755 linuxury users -"

    # SSH directory with correct permissions
    "d ${config.home.homeDirectory}/.ssh  0700 linuxury users -"
  ];

  # =========================================================================
  # Dotfiles — symlinked from dotfiles/ in your repo
  # =========================================================================
  home.file = {
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
    # ~/Pictures/Wallpapers → ~/nixos-config/assets/Wallpapers/<wallpaperDir>
    #
    # wallpaperDir is passed per-host from flake.nix:
    #   ThinkPad   → "4k"
    #   Ryzen5900x → "3440x1440"
    #
    # The wallpaper slideshow script always reads from ~/Pictures/Wallpapers
    # so it works identically on both machines without any changes.
    #
    # mkOutOfStoreSymlink creates a symlink to a path outside the Nix store.
    # Wallpapers live inside the repo so no separate clone is needed.
    # -----------------------------------------------------------------------
    "Pictures/Wallpapers".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/assets/Wallpapers/${wallpaperDir}";

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
  # VSCodium — GUI editor
  # Settings managed by VSCodium directly (edit via Ctrl+, in the app)
  #
  # mutableExtensionsDir = true  — each Nix extension is symlinked
  # individually, leaving the extensions dir itself writable so VSCodium
  # can store metadata and you can install additional extensions via the UI.
  #
  # product.json points VSCodium at the VS Code marketplace so extensions
  # like Claude that are not on Open VSX are available to install.
  # =========================================================================
  programs.vscode = {
    enable               = true;
    package              = pkgs.vscodium;
    mutableExtensionsDir = true;
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
  };

  # Point VSCodium at the VS Code marketplace so Claude and other
  # marketplace-only extensions can be installed through the UI.
  home.file.".config/VSCodium/product.json".text = builtins.toJSON {
    extensionsGallery = {
      serviceUrl      = "https://marketplace.visualstudio.com/_apis/public/gallery";
      cacheUrl        = "https://vscode.blob.core.windows.net/gallery/index";
      itemUrl         = "https://marketplace.visualstudio.com/items";
      controlUrl      = "";
      recommendationsUrl = "";
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
  # Hytale — automatic flatpak installation from bundled file
  #
  # Hytale is not on Flathub yet. We bundle the flatpak from the developer
  # directly in the assets repo and install it automatically on first login.
  #
  # Source: https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak
  # Store at: ~/assets/flatpaks/hytale-launcher-latest.flatpak
  # =========================================================================
  systemd.user.services.hytale-flatpak-install = {
    Unit = {
      Description         = "Install Hytale launcher from bundled flatpak";
      After               = [ "graphical-session.target" ];
      Wants               = [ "graphical-session.target" ];
      ConditionPathExists = "!/var/lib/flatpak/app/com.hytale.Hytale";
    };

    Service = {
      Type      = "oneshot";
      Restart   = "no";
      ExecStart = "${pkgs.writeShellScript "install-hytale-linuxury" ''
        FLATPAK_FILE="$HOME/assets/flatpaks/hytale-launcher-latest.flatpak"

        if flatpak info com.hytale.Hytale &>/dev/null; then
          echo "Hytale already installed, skipping."
          exit 0
        fi

        if [ ! -f "$FLATPAK_FILE" ]; then
          echo "Hytale flatpak not found at $FLATPAK_FILE"
          notify-send \
            --app-name "Hytale" \
            --icon "dialog-warning" \
            --urgency normal \
            "Hytale Not Installed" \
            "Flatpak bundle not found. Clone the assets repo first."
          exit 1
        fi

        notify-send \
          --app-name "Hytale" \
          --icon "system-software-install" \
          --urgency normal \
          "Installing Hytale" \
          "Installing Hytale launcher, this may take a moment..."

        if flatpak install --user --noninteractive "$FLATPAK_FILE"; then
          notify-send \
            --app-name "Hytale" \
            --icon "system-software-install" \
            --urgency normal \
            "Hytale Installed" \
            "Hytale launcher is ready to play!"
        else
          notify-send \
            --app-name "Hytale" \
            --icon "dialog-error" \
            --urgency critical \
            "Hytale Install Failed" \
            "Check journalctl --user -u hytale-flatpak-install for details."
        fi
      ''}";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # =========================================================================
  # Personal packages
  #
  # Packages already provided elsewhere — do not re-add:
  #   common.nix          → fastfetch, btop
  #   graphical-base.nix  → ghostty, kitty, mpv, imv, wl-clipboard, xdg-utils
  #   gaming.nix          → prismlauncher, mcpelauncher-ui-qt, jdk17
  #   development.nix     → nil, nixfmt-rfc-style, direnv
  # =========================================================================
  home.packages = with pkgs; [

    # Shell tools
    topgrade    # One-command updater — Nix, cargo, flatpaks, etc.

    # File management
    yazi        # Terminal file manager with previews
    eza         # Modern ls replacement with colors and icons
    bat         # cat with syntax highlighting and line numbers

    # Development helpers
    lazygit     # TUI for git — stage, commit, branch all in one
    gh          # GitHub CLI — PRs, issues from terminal
    delta       # Pretty diff viewer — integrates with git

    # System monitoring
    dust        # Visual disk usage — like du but readable
    procs       # Modern ps replacement with color and filtering

    # Networking
    whois       # Domain registration lookup
    traceroute  # Trace network path to a host

    # Misc utilities
    p7zip       # Extract .7z, .rar, and many other archive formats
    imagemagick # CLI image conversion and manipulation
    claude-code # Claude Code CLI — AI coding assistant
  ];
}
