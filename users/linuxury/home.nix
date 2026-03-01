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

let
  # ===========================================================================
  # BreezeX cursor theme — not in nixpkgs, fetched from GitHub releases
  #
  # BreezeX is a refined KDE Breeze cursor with larger sizes and cleaner
  # rendering. The v2.0.1 bundle ships three dark variants: Black, Dark, Light.
  # BreezeX-Light is set as default here.
  #
  # To upgrade: run nix-prefetch-url --unpack <new release URL> and update
  # the sha256 below.
  # ===========================================================================
  breezex-cursors = pkgs.stdenv.mkDerivation {
    pname   = "breezex-cursor-theme";
    version = "2.0.1";

    src = pkgs.fetchzip {
      url        = "https://github.com/ful1e5/BreezeX_Cursor/releases/download/v2.0.1/BreezeX.tar.xz";
      sha256     = "10fbvbls52cgp5kshlcxbh3nqarh2mwhpj0w5kkk4hrl3sdc1bcj";
      stripRoot  = false; # archive has multiple top-level dirs (BreezeX, BreezeX-Black, …)
    };

    dontBuild     = true;
    dontConfigure = true;

    installPhase = ''
      mkdir -p $out/share/icons
      cp -r . $out/share/icons/
    '';
  };

in

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
  # Without this, apps like Zed can't find binaries installed via
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
    # Avatar and other asset dirs are also symlinked from the repo.
    "d ${config.home.homeDirectory}/assets                         0755 linuxury users -"
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

    # ~/assets/Avatar → ~/nixos-config/assets/Avatar (avatar images in repo)
    "assets/Avatar".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/assets/Avatar";

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

  # Remove old plain directory so home-manager can create the Avatar symlink.
  # (tmpfiles previously created ~/assets/Avatar as a dir; first activation
  # after this change swaps it for the repo symlink.)
  home.activation.migrateAvatarDir = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -d "$HOME/assets/Avatar" ] && [ ! -L "$HOME/assets/Avatar" ]; then
      rmdir "$HOME/assets/Avatar" 2>/dev/null || true
    fi
  '';

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
  #
  # Package is overridden to remove the upstream Helix.desktop so it doesn't
  # appear alongside our custom xdg.desktopEntries.helix below.
  # =========================================================================
  programs.helix = {
    enable  = true;
    package = pkgs.helix.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        rm -f $out/share/applications/Helix.desktop
      '';
    });
  };

  # Override Helix desktop entry so clicking the icon opens it in Ghostty.
  # Helix's package installs Helix.desktop (Terminal=true), which COSMIC can't
  # use without a configured default terminal. We remove that file from the
  # package and replace it with our own helix.desktop (Terminal=false, explicit
  # Ghostty launch) so only one entry appears in the app menu.
  xdg.desktopEntries.helix = {
    name        = "Helix";
    genericName = "Text Editor";
    comment     = "A post-modern text editor";
    exec        = "ghostty -e hx %F";
    terminal    = false;
    categories  = [ "Utility" "TextEditor" ];
    icon        = "helix";
    mimeType    = [
      "text/plain"
      "text/x-makefile"
      "text/x-script.python"
      "text/x-c"
      "text/x-c++"
      "text/x-rust"
      "application/x-shellscript"
    ];
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
  # Cursor theme — BreezeX (white)
  #
  # home.pointerCursor handles three layers at once:
  #   1. Sets XCURSOR_THEME + XCURSOR_SIZE in the systemd user environment
  #      so Wayland compositors (COSMIC, Hyprland, Niri) pick it up
  #   2. Creates ~/.icons/default/index.theme for X11 fallback
  #   3. Writes cursor settings to GTK config (gtk.enable = true below)
  # =========================================================================
  home.pointerCursor = {
    name    = "BreezeX-Light";
    package = breezex-cursors;
    size    = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # =========================================================================
  # GTK theme — icons and cursor
  #
  # COSMIC and most apps respect gtk-icon-theme-name and
  # gtk-cursor-theme-name from settings.ini. Setting them here means
  # GTK3, GTK4, and libadwaita apps all get consistent theming.
  # =========================================================================
  gtk = {
    enable = true;
    iconTheme = {
      name    = "Tela";
      package = pkgs.tela-icon-theme;
    };
    cursorTheme = {
      name    = "BreezeX-Light";
      package = breezex-cursors;
      size    = 24;
    };
  };

  # =========================================================================
  # COSMIC appearance config
  #
  # COSMIC stores each setting as its own file under
  # ~/.config/cosmic/com.system76.CosmicTk/v1/.
  # Values are serialized as RON (Rusty Object Notation) — plain strings
  # are just quoted strings, integers are bare numbers.
  #
  # Writing these declaratively means COSMIC always starts with the correct
  # theme regardless of what its UI may have previously set.
  # =========================================================================
  home.file.".config/cosmic/com.system76.CosmicTk/v1/icon_theme".text  = ''"Tela"'';
  home.file.".config/cosmic/com.system76.CosmicTk/v1/cursor_theme".text = ''"BreezeX-Light"'';
  home.file.".config/cosmic/com.system76.CosmicTk/v1/cursor_size".text  = "24";

  # =========================================================================
  # Hytale — automatic flatpak installation
  #
  # Hytale is not on Flathub yet. On first login the service tries to find
  # a pre-downloaded bundle at ~/assets/flatpaks/ and falls back to fetching
  # it directly from the developer's CDN if the file isn't there yet.
  #
  # Source: https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak
  # =========================================================================
  systemd.user.services.hytale-flatpak-install = {
    Unit = {
      Description         = "Install Hytale launcher from flatpak";
      After               = [ "graphical-session.target" "network-online.target" ];
      Wants               = [ "graphical-session.target" "network-online.target" ];
      ConditionPathExists = "!%h/.local/share/flatpak/app/com.hytale.Hytale";
    };

    Service = {
      Type      = "oneshot";
      Restart   = "no";
      ExecStart = "${pkgs.writeShellScript "install-hytale-linuxury" ''
        FLATPAK="${pkgs.flatpak}/bin/flatpak"
        CURL="${pkgs.curl}/bin/curl"
        FLATPAK_FILE="$HOME/assets/flatpaks/hytale-launcher-latest.flatpak"
        HYTALE_URL="https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak"

        if $FLATPAK info --user com.hytale.Hytale &>/dev/null; then
          echo "Hytale already installed, skipping."
          exit 0
        fi

        # Ensure Flathub is available so flatpak can pull required runtimes
        # (e.g. org.freedesktop.Platform) when installing the bundle.
        $FLATPAK remote-add --user --if-not-exists flathub \
          https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

        # If the bundled file isn't present, download it from the official CDN.
        if [ ! -f "$FLATPAK_FILE" ]; then
          echo "Local bundle not found — downloading from $HYTALE_URL"
          mkdir -p "$(dirname "$FLATPAK_FILE")"
          if ! $CURL -L --fail -o "$FLATPAK_FILE" "$HYTALE_URL"; then
            echo "ERROR: Could not download Hytale. Check internet or clone the assets repo."
            exit 1
          fi
        fi

        echo "Installing Hytale launcher..."
        $FLATPAK install --user --noninteractive "$FLATPAK_FILE" || true

        # Verify the app is actually present — covers fresh install and the
        # edge case where flatpak returns non-zero because it was already installed.
        if $FLATPAK info --user com.hytale.Hytale &>/dev/null; then
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
  # Hytale — Flatpak rendering fix for COSMIC (Wayland)
  #
  # Hytale's Electron-based launcher renders blank content on COSMIC because
  # it tries to use native Wayland GPU rendering, which behaves differently
  # from KWin. Forcing XWayland mode (ELECTRON_OZONE_PLATFORM_HINT=x11) makes
  # the renderer behave exactly as it does under KDE/X11 where it works fine.
  #
  # flatpak override is idempotent — safe to re-apply on every HM activation.
  # =========================================================================
  home.activation.hytale-wayland-fix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.flatpak}/bin/flatpak override --user \
      --env=ELECTRON_OZONE_PLATFORM_HINT=x11 \
      com.hytale.Hytale 2>/dev/null || true
  '';

  # =========================================================================
  # Personal packages
  #
  # Packages already provided elsewhere — do not re-add:
  #   common.nix          → fastfetch, btop, rsync
  #   graphical-base.nix  → ghostty, kitty, showtime, loupe, amberol, papers,
  #                          gnome-disk-utility, mission-center, wl-clipboard,
  #                          xdg-utils, kdeconnect
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

    # Communication
    thunderbird # Email client — personal use

    # Internet
    fluent-reader # RSS feed reader — clean GTK app for following news/blogs
    obs-studio    # Screen recording and streaming

    # Theming — icons and cursors
    tela-icon-theme # Clean flat icon set, consistent across GNOME/COSMIC apps
    breezex-cursors # BreezeX-Light cursor (defined above as custom derivation)

    # Misc utilities
    p7zip       # Extract .7z, .rar, and many other archive formats
    imagemagick # CLI image conversion and manipulation
    claude-code # Claude Code CLI — AI coding assistant
  ];
}
