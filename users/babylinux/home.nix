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
#   - Shares terminal dotfiles with linuxury (kitty)
# ===========================================================================

# Single function — wallpaperDir comes from extraSpecialArgs in flake.nix
{ config, pkgs, inputs, lib, wallpaperDir, ... }:

let
  # ===========================================================================
  # BreezeX cursor theme — not in nixpkgs, fetched from GitHub releases
  #
  # Same derivation used by linuxury in cosmic-theme.nix.
  # BreezeX-Light is a refined KDE Breeze cursor with larger sizes.
  # ===========================================================================
  breezex-cursors = pkgs.stdenv.mkDerivation {
    pname   = "breezex-cursor-theme";
    version = "2.0.1";

    src = pkgs.fetchzip {
      url       = "https://github.com/ful1e5/BreezeX_Cursor/releases/download/v2.0.1/BreezeX.tar.xz";
      sha256    = "10fbvbls52cgp5kshlcxbh3nqarh2mwhpj0w5kkk4hrl3sdc1bcj";
      stripRoot = false; # archive has multiple top-level dirs (BreezeX, BreezeX-Black, …)
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
    ../../modules/development/neovim/default.nix
    ../../modules/system/graphical/helium/default.nix
    ../../modules/system/graphical/hytale/default.nix
  ];

  programs.hytale.enable = true;

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
      "application/pdf"   = "org.gnome.Papers.desktop";            # PDF → Document Viewer
      "application/x-pdf" = "org.gnome.Papers.desktop";
    };
  };

  xdg.configFile."mimeapps.list".force = true;

  # =========================================================================
  # XDG User Directories
  # =========================================================================
  xdg.userDirs = {
    enable            = true;
    createDirectories = true;
    setSessionVariables = true; # Silence HM 26.05 default change warning

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
    # SSH directory with correct permissions
    "d ${config.home.homeDirectory}/.ssh  0700 babylinux users -"
  ];

  # =========================================================================
  # Dotfiles — shared terminal setup with linuxury
  # =========================================================================
  # Migration — remove old plain dirs before HM creates symlinks in their place
  # =========================================================================
  home.activation.migrateKdeGtkFiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # BreezeX cursor dir written by a previous session — HM will symlink it
    rm -rf "$HOME/.icons/BreezeX-Light"
    # kdeglobals/kcminputrc were previously HM-managed symlinks — remove them
    # so HM doesn't conflict, and initKdeConfig below writes them as regular files
    [ -L "$HOME/.config/kdeglobals" ]  && rm -f "$HOME/.config/kdeglobals"
    [ -L "$HOME/.config/kcminputrc" ]  && rm -f "$HOME/.config/kcminputrc"
  '';

  home.activation.migrateAssetDirs = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # Old ~/Pictures/Avatar plain dir → now symlinked at ~/Pictures/Avatar
    if [ -d "$HOME/Pictures/Avatar" ] && [ ! -L "$HOME/Pictures/Avatar" ]; then
      rmdir "$HOME/Pictures/Avatar" 2>/dev/null || true
    fi
    # Old ~/Documents/assets/flatpaks plain dir → now symlinked at ~/Documents/assets/flatpaks
    if [ -d "$HOME/Documents/assets/flatpaks" ] && [ ! -L "$HOME/Documents/assets/flatpaks" ]; then
      rmdir "$HOME/Documents/assets/flatpaks" 2>/dev/null || true
    fi
    # Remove ~/Documents/assets parent if empty
    if [ -d "$HOME/Documents/assets" ] && [ ! -L "$HOME/Documents/assets" ]; then
      rmdir "$HOME/Documents/assets" 2>/dev/null || true
    fi
    # Stale fontconfig file left by a previous HM generation
    if [ -f "$HOME/.config/fontconfig/conf.d/10-hm-fonts.conf" ] && [ ! -L "$HOME/.config/fontconfig/conf.d/10-hm-fonts.conf" ]; then
      rm "$HOME/.config/fontconfig/conf.d/10-hm-fonts.conf" 2>/dev/null || true
    fi
  '';

  # =========================================================================
  home.file = {
    # Starship prompt — shared config
    ".config/starship.toml".source = ../../dotfiles/starship/starship.toml;

    # Fastfetch — shared config
    ".config/fastfetch".source = ../../dotfiles/fastfetch;

    # Kitty terminal — base config; colors written by matugen at runtime
    ".config/kitty/kitty.conf".source = ../../dotfiles/kitty/kitty.conf;


    # Nano — for quick root edits
    ".nanorc".source = ../../dotfiles/nano/.nanorc;

    # -----------------------------------------------------------------------
    # Wallpaper symlink
    #
    # ~/Pictures/Wallpapers → ~/assets/Wallpapers/<wallpaperDir>
    # Both her machines use "4k" — set in flake.nix
    # -----------------------------------------------------------------------
    "Pictures/Wallpapers".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/assets/Wallpapers/${wallpaperDir}";

    # ~/Pictures/Avatar → nixos-config/assets/Avatar (family profile photos)
    "Pictures/Avatar".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/assets/Avatar";

    # ~/Pictures/Fastfetch → nixos-config/assets/Fastfetch (fastfetch logo images)
    "Pictures/Fastfetch".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/assets/Fastfetch";

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
        # agenix — run from secrets/ dir without changing shell's cwd
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
    signing.format = null; # Silence HM 25.05 default change warning
    settings = {
      user.name  = "babylinux";
      user.email = "her@email.com"; # Replace with her actual email
      init.defaultBranch = "main";
      pull.rebase        = false;
    };
  };

  # =========================================================================
  # Hytale — auto-install + overrides (see modules/system/graphical/hytale/default.nix)
  # =========================================================================

  # =========================================================================
  # Cursor — BreezeX-Light
  #
  # home.pointerCursor sets three things at once:
  #   1. XCURSOR_THEME + XCURSOR_SIZE in the systemd user environment
  #      so kwin_wayland picks it up on session start
  #   2. ~/.icons/default/index.theme for X11 fallback
  #   3. GTK cursor config (via gtk.enable below)
  # =========================================================================
  home.pointerCursor = {
    name       = "BreezeX-Light";
    package    = breezex-cursors;
    size       = 24;
    gtk.enable = false; # KDE manages GTK theming — don't let HM overwrite it
  };

  # =========================================================================
  # KDE initial config — written as regular files, not HM symlinks
  #
  # kdeglobals and kcminputrc must be writable by KDE at runtime:
  # KDE fills in [Colors:Button], [Colors:View], etc. sections when it loads
  # the color scheme. A read-only Nix store symlink silently blocks those
  # writes, leaving the color tables empty → apps fall back to light theme.
  #
  # Strategy: write the files once (on first setup or if missing) as regular
  # writable files. KDE can then populate color values and persist user changes.
  # Settings survive rebuilds — activation only writes if the file is absent.
  # =========================================================================
  home.activation.initKdeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    KDEGLOBALS="$HOME/.config/kdeglobals"
    if [ ! -f "$KDEGLOBALS" ]; then
      cat > "$KDEGLOBALS" << 'EOF'
[Icons]
Theme=breeze-chameleon-dark

[General]
ColorScheme=BreezeDark
shadeSortColumn=true

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=false
widgetStyle=darkly
EOF
    fi

    KCMINPUTRC="$HOME/.config/kcminputrc"
    if [ ! -f "$KCMINPUTRC" ]; then
      cat > "$KCMINPUTRC" << 'EOF'
[Mouse]
cursorTheme=BreezeX-Light
cursorSize=24
EOF
    fi
  '';

  # =========================================================================
  # SSH agent
  # =========================================================================
  services.ssh-agent.enable = true;

  # =========================================================================
  # VSCodium — declarative extensions
  #
  # Settings are managed via home.file (mkOutOfStoreSymlink) so the file
  # stays writable from the GUI while still being tracked in the repo.
  #
  # Extensions fetched from Open VSX — not VS Marketplace (VSCodium ToS).
  # =========================================================================
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    mutableExtensionsDir = true;
    profiles.default.extensions =
      (with pkgs.vscode-extensions; [
        catppuccin.catppuccin-vsc
        golang.go
      ])
      ++ [
        # Claude Code — Open VSX linux-x64 variant
        (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
          mktplcRef = {
            publisher = "anthropic";
            name = "claude-code";
            version = "2.1.120";
          };
          vsix = pkgs.fetchurl {
            url = "https://open-vsx.org/api/Anthropic/claude-code/linux-x64/2.1.120/file/Anthropic.claude-code-2.1.120@linux-x64.vsix";
            sha256 = "1n4gl8f4csq4ngmw7dksiaxhlglsswgypynnjpzyzskn4c94c1c5";
          };
        })
        # flow-dawn icon theme
        (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
          mktplcRef = {
            publisher = "thang-nm";
            name = "flow-icons";
            version = "1.3.2";
          };
          vsix = pkgs.fetchurl {
            url = "https://open-vsx.org/api/thang-nm/flow-icons/1.3.2/file/thang-nm.flow-icons-1.3.2.vsix";
            sha256 = "1lwsjawvhy3yzw7dl93ac4vyvfmcwbrs58s3wd2az1ld3d6m3drv";
          };
        })
        # OpenCode AI assistant
        (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
          mktplcRef = {
            publisher = "sst-dev";
            name = "opencode";
            version = "0.0.13";
          };
          vsix = pkgs.fetchurl {
            url = "https://open-vsx.org/api/sst-dev/opencode/0.0.13/file/sst-dev.opencode-0.0.13.vsix";
            sha256 = "1m301j2qbym3j2qnck76jyxakca3h1qiybc2r7wy7z11m98mg9z9";
          };
        })
        # JetBrains-style file icons
        (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
          mktplcRef = {
            publisher = "fogio";
            name = "jetbrains-file-icon-theme";
            version = "1.5.0";
          };
          vsix = pkgs.fetchurl {
            url = "https://open-vsx.org/api/fogio/jetbrains-file-icon-theme/1.5.0/file/fogio.jetbrains-file-icon-theme-1.5.0.vsix";
            sha256 = "1jdha38c61hlz5hj59xzq89zprcwa6qhfg9pkqlpn017b2ccc4x3";
          };
        })
      ];
    profiles.default.userSettings =
      (builtins.fromJSON (builtins.readFile ../../dotfiles/vscodium/settings.json))
      // {
        "claudeCode.claudeProcessWrapper" = "/etc/profiles/per-user/${config.home.username}/bin/claude";
      };
  };

  # =========================================================================
  # VSCodium — Claude Code NixOS wrapper
  #
  # The Claude Code extension bundles a generic Linux binary that can't run
  # on NixOS (dynamic linker mismatch). This replaces it with a thin wrapper
  # that calls the Nix-installed claude binary if present.
  # No-op if claude is not installed.
  # =========================================================================
  home.activation.vscodiumClaudeWrapper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CLAUDE_REAL="/etc/profiles/per-user/${config.home.username}/bin/claude"
    EXT_DIR="$HOME/.vscode-oss/extensions"

    for ext_claude in "$EXT_DIR"/anthropic.claude-code-*/resources/native-binary/claude; do
      [ -e "$ext_claude" ] || continue
      case "$ext_claude" in /nix/store/*) continue;; esac
      grep -q "exec $CLAUDE_REAL" "$ext_claude" 2>/dev/null && continue
      [ -f "$ext_claude.orig" ] || mv "$ext_claude" "$ext_claude.orig"
      [ -f "$ext_claude.orig" ] && rm -f "$ext_claude"
      printf '#!/bin/sh\nexec %s "$@"\n' "$CLAUDE_REAL" > "$ext_claude"
      chmod +x "$ext_claude"
    done
  '';

  # =========================================================================
  # Obsidian vault directory
  #
  # Creates ~/Obsidian on first activation so Syncthing has a target path
  # to sync into. Without this the syncthing service logs an error on boot
  # because the folder doesn't exist yet.
  # =========================================================================
  home.activation.obsidianVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/Obsidian"
  '';

  # Personal packages live in modules/users/babylinux-packages.nix
}
