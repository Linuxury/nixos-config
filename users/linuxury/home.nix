# ===========================================================================
# users/linuxury/home.nix — Home Manager config for linuxury
#
# Machines: ThinkPad (laptop), Ryzen5900x (desktop)
# Role: Admin, developer, power user
#
# Per-host values are injected via extraSpecialArgs in flake.nix:
#   wallpaperDir     ThinkPad → "4k" | Ryzen5900x → "3440x1440"
#   hypridleProfile  ThinkPad → "laptop" | Ryzen5900x → "desktop"
#
# ===========================================================================

# wallpaperDir and hypridleProfile come from extraSpecialArgs in flake.nix
{
  config,
  pkgs,
  inputs,
  lib,
  wallpaperDir,
  hypridleProfile,
  ...
}:

{
  imports = [
    ../../modules/home/neovim.nix
    ../../modules/home/helium.nix
    ../../modules/home/hytale.nix
  ];

  # =========================================================================
  # Home Manager basics
  # =========================================================================
  home.username = "linuxury";
  home.homeDirectory = "/home/linuxury";
  home.stateVersion = "24.11";

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
  # XDG MIME type associations
  #
  # Tells the desktop environment which app opens each file type.
  # Without this, audio files open in whatever the DE guesses (often nothing).
  # G4Music's desktop entry ID: com.github.neithern.g4music.desktop
  # =========================================================================
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "audio/mpeg" = "com.github.neithern.g4music.desktop"; # MP3
      "audio/ogg" = "com.github.neithern.g4music.desktop"; # OGG Vorbis
      "audio/flac" = "com.github.neithern.g4music.desktop"; # FLAC
      "audio/x-flac" = "com.github.neithern.g4music.desktop";
      "audio/wav" = "com.github.neithern.g4music.desktop"; # WAV
      "audio/x-wav" = "com.github.neithern.g4music.desktop";
      "audio/mp4" = "com.github.neithern.g4music.desktop"; # M4A / AAC
      "audio/aac" = "com.github.neithern.g4music.desktop";
      "audio/x-m4a" = "com.github.neithern.g4music.desktop";
      "audio/opus" = "com.github.neithern.g4music.desktop"; # Opus
      "audio/webm" = "com.github.neithern.g4music.desktop";
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "application/pdf"   = "org.gnome.Papers.desktop";   # PDF → Document Viewer
      "application/x-pdf" = "org.gnome.Papers.desktop";
    };
  };

  # mimeapps.list may already exist from a previous manual edit — allow HM
  # to take ownership so the xdg.mimeApps declarations above take effect.
  xdg.configFile."mimeapps.list".force = true;

  # =========================================================================
  # XDG User Directories
  # =========================================================================
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true; # Silence HM 26.05 default change warning

    desktop = "${config.home.homeDirectory}/Desktop";
    documents = "${config.home.homeDirectory}/Documents";
    download = "${config.home.homeDirectory}/Downloads";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
    templates = "${config.home.homeDirectory}/Templates";
    publicShare = "${config.home.homeDirectory}/Public";
  };

  # =========================================================================
  # Extra directories
  # =========================================================================
  systemd.user.tmpfiles.rules = [
    # ~/.agents — AI config root, synced via Syncthing
    "d ${config.home.homeDirectory}/.agents                  0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/Claude           0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/OpenCode         0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/Shared           0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/Shared/mcp-servers 0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/memory           0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/backups          0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/skills           0755 linuxury users -"

    # SSH directory with correct permissions
    "d ${config.home.homeDirectory}/.ssh  0700 linuxury users -"
  ];

  # =========================================================================
  # Dotfiles — symlinked from dotfiles/ in your repo
  # =========================================================================
  home.file = {
    # Starship prompt
    ".config/starship.toml".source = ../../dotfiles/starship/starship.toml;

    # Fastfetch
    ".config/fastfetch".source = ../../dotfiles/fastfetch;

    # Topgrade — NixOS flake version
    ".config/topgrade.toml".source = ../../dotfiles/topgrade/topgrade-nixos.toml;

    # MangoHud — performance overlay for gaming
    ".config/MangoHud".source = ../../dotfiles/MangoHud;

    # Kitty terminal — base config; colors written by matugen at runtime
    ".config/kitty/kitty.conf".source = ../../dotfiles/kitty/kitty.conf;

    # Swappy — screenshot annotation tool
    ".config/swappy/config".source = ../../dotfiles/swappy/config;

    # Hyprland — full config directory (entry point + all modules)
    # Live symlink so edits in the repo take effect immediately via hyprctl reload
    ".config/hypr".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/hypr";

    # MangoWC — autostart script (live symlink; edits take effect via SUPER+r)
    # config.conf is NOT a symlink — it is written by matugen on each wallpaper
    # change so border/focus colors stay in sync with the current palette.
    # The seed activation below creates an initial copy if the file is absent.
    ".config/mango/autostart.sh".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/mangowc/autostart.sh";

    # Zed editor
    ".config/zed/settings.json".source = ../../dotfiles/zed/settings.json;

    # OpenCode — matugen theme (colors regenerated by matugen at wallpaper change)
    ".config/opencode/tui.json" = {
      source = ../../dotfiles/opencode/tui.json;
      force = true;
    };

    # -----------------------------------------------------------------------
    # AI config symlinks — source files live in ~/.agents/{Claude,OpenCode,Shared}/
    # synced via Syncthing. home-manager only creates the outbound symlinks.
    # On a fresh host: rebuild creates symlinks, Syncthing populates ~/.agents.
    #
    # ~/.claude is a full directory symlink to ~/.agents/Claude/ so all of
    # Claude Code's runtime data (history, sessions, projects, credentials)
    # lands in ~/.agents/Claude/ and syncs across hosts via Syncthing.
    # -----------------------------------------------------------------------
    "AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/Shared/AGENTS.md";
    "CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/Claude/CLAUDE.md";
    ".claude".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/Claude";
    ".config/opencode/opencode.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/OpenCode/settings.json";
    ".claude.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/Claude/state.json";


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
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/assets/Wallpapers/${wallpaperDir}";

    # -----------------------------------------------------------------------
    # Picture assets — symlinked from nixos-config/assets/ into ~/Pictures/
    #
    # This puts all family photos and game art where the DE and image
    # viewer can discover them naturally, without a detour through ~/assets/.
    # -----------------------------------------------------------------------

    # ~/Pictures/Avatar → nixos-config/assets/Avatar (family profile photos)
    "Pictures/Avatar".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/assets/Avatar";

    # ~/Pictures/Minecraft → nixos-config/assets/Minecraft (skins, packs art)
    "Pictures/Minecraft".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/assets/Minecraft";

    # ~/Pictures/SteamGridDB → nixos-config/assets/SteamGridDB (Steam cover art)
    "Pictures/SteamGridDB".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/assets/SteamGridDB";

    # ~/Pictures/Fastfetch → nixos-config/assets/Fastfetch (fastfetch logo images)
    "Pictures/Fastfetch".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/assets/Fastfetch";

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
        SetEnv              TERM=xterm-256color

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

      Host radxa-local
        HostName     10.0.0.5
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host minisforum-local
        HostName     10.0.0.7
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

      Host thinkpad
        HostName     ThinkPad
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host ryzen5900x
        HostName     Ryzen5900x
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519
    '';
  };

  # Remove old plain directories so home-manager can create symlinks.
  # Previous layout had ~/assets/Avatar as a tmpfiles dir; now it's a symlink
  # at ~/Pictures/Avatar. Same for Minecraft and SteamGridDB.
  # Remove manually-created AI symlinks/files so home-manager can take ownership.
  # Safe to run repeatedly — only acts on symlinks or plain files, never dirs.
  home.activation.migrateAiSymlinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # Clean up top-level symlinks/files so HM can recreate them
    for f in \
      "$HOME/AGENTS.md" \
      "$HOME/CLAUDE.md" \
      "$HOME/.config/opencode/opencode.json" \
      "$HOME/.claude.json"; do
      if [ -L "$f" ] || [ -f "$f" ]; then
        rm -f "$f"
      fi
    done

    # Migrate ~/.claude real directory → ~/.agents/Claude/ then remove it
    # so HM can create ~/.claude as a directory symlink to ~/.agents/Claude/.
    # Only runs once — skipped if ~/.claude is already a symlink.
    if [ -d "$HOME/.claude" ] && [ ! -L "$HOME/.claude" ]; then
      for item in projects history.jsonl todos sessions backups .credentials.json; do
        src="$HOME/.claude/$item"
        dst="$HOME/.agents/Claude/$item"
        if [ -e "$src" ] && [ ! -L "$src" ] && [ ! -e "$dst" ]; then
          mv "$src" "$dst"
        fi
      done
      rm -rf "$HOME/.claude"
    fi

    # Remove old flat-layout stale files if Syncthing left them behind
    for f in \
      "$HOME/.agents/AGENTS.md" \
      "$HOME/.agents/CLAUDE.md" \
      "$HOME/.agents/claude-settings.json" \
      "$HOME/.agents/claude-settings.local.json" \
      "$HOME/.agents/claude-state.json" \
      "$HOME/.agents/opencode-settings.json" \
      "$HOME/.agents/opencode-instructions.md" \
      "$HOME/.agents/mcp-servers.json" \
      "$HOME/.agents/sync-configs.sh"; do
      if [ -f "$f" ] && [ ! -L "$f" ]; then
        rm -f "$f"
      fi
    done
  '';

  home.activation.migrateAssetDirs = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # Old ~/assets/Avatar plain dir → now symlinked at ~/Pictures/Avatar
    if [ -d "$HOME/assets/Avatar" ] && [ ! -L "$HOME/assets/Avatar" ]; then
      rmdir "$HOME/assets/Avatar" 2>/dev/null || true
    fi
    # Old ~/assets/Minecraft plain dir → now symlinked at ~/Pictures/Minecraft
    if [ -d "$HOME/assets/Minecraft" ] && [ ! -L "$HOME/assets/Minecraft" ]; then
      rmdir "$HOME/assets/Minecraft" 2>/dev/null || true
    fi
    # Old ~/assets/SteamGridDB plain dir → now symlinked at ~/Pictures/SteamGridDB
    if [ -d "$HOME/assets/SteamGridDB" ] && [ ! -L "$HOME/assets/SteamGridDB" ]; then
      rmdir "$HOME/assets/SteamGridDB" 2>/dev/null || true
    fi
    # Old ~/assets/flatpaks plain dir → moved to ~/Documents/assets/flatpaks
    if [ -d "$HOME/assets/flatpaks" ] && [ ! -L "$HOME/assets/flatpaks" ]; then
      rmdir "$HOME/assets/flatpaks" 2>/dev/null || true
    fi
  '';

  # =========================================================================
  # Zsh shell
  # =========================================================================
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;

    # fast-syntax-highlighting — richer colors and faster than zsh-syntax-highlighting
    plugins = [
      {
        name = "fast-syntax-highlighting";
        src = pkgs.zsh-fast-syntax-highlighting;
        file = "share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh";
      }
    ];

    # Abbreviations expand inline before running — you see the full command first.
    # Managed declaratively by Home Manager via programs.zsh.zsh-abbr.
    zsh-abbr = {
      enable = true;
      abbreviations = {
        # agenix — run from secrets/ dir without changing shell's cwd
        age-edit = "env -C ~/nixos-config/secrets nix run github:ryantm/agenix -- -e";
        age-rekey = "env -C ~/nixos-config/secrets nix run github:ryantm/agenix -- -r";

        # Obsidian notes
        notes = "cd ~/Obsidian && nvim .";

        # Snapper snapshot management
        snaps = "sudo snapper -c root list";
        snapsh = "sudo snapper -c home list";
        snapc = "sudo snapper -c root create --description";
      };
    };

    shellAliases = {
      # eza — modern ls with colors, icons, and git status (eza is in linuxury-packages.nix)
      ll = "eza -la --color=always --icons --group-directories-first --git";
    };

    # Shared shell initialization — env vars, PATH, fastfetch, nru function
    initContent = lib.fileContents ../../dotfiles/zsh/zshrc;
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
    enable = true;
    signing.format = null; # Silence HM 25.05 default change warning (no signing configured)
    settings = {
      user.name = "Linuxury";
      user.email = "linuxurypr@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        lg = "log --oneline --graph --decorate";
      };
    };
  };

  # Neovim config is now managed by the normie-nvim activation script in
  # modules/home/neovim.nix — no overrides needed here.

  # Desktop entry — opens Neovim in Kitty
  xdg.desktopEntries.nvim = {
    name = "Neovim";
    genericName = "Text Editor";
    comment = "Hyperextensible Vim-based text editor";
    exec = "kitty nvim %F";
    terminal = false;
    categories = [
      "Utility"
      "TextEditor"
    ];
    icon = "nvim";
    mimeType = [
      "text/plain"
      "text/x-makefile"
      "text/x-script.python"
      "text/x-c"
      "text/x-c++"
      "text/x-rust"
      "application/x-shellscript"
      "application/json"
      "application/x-yaml"
      "application/toml"
    ];
  };

  # =========================================================================
  # Zoxide — smarter cd
  # =========================================================================
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # =========================================================================
  # FZF — fuzzy finder
  # =========================================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # =========================================================================
  # Direnv — auto-loads .envrc on cd (nix develop shells, project env vars)
  # =========================================================================
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # =========================================================================
  # VSCodium — declarative extensions
  #
  # Settings are managed separately via home.file (mkOutOfStoreSymlink) so
  # the file stays writable from the GUI while still being tracked in the repo.
  #
  # Extensions not in nixpkgs are fetched from Open VSX using the vsix
  # parameter so they don't hit the VS Marketplace (VSCodium ToS).
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
        # Claude Code — Open VSX linux-x64 variant (nixpkgs version has stale hash)
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
        # Flow Icons — provides flow-deep, flow-dim, flow-dawn themes (free v1.x)
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
  };

  # VSCodium settings — generated at activation so the license key can be
  # injected from agenix without ever touching the tracked dotfile.
  # Base settings live in dotfiles/vscodium/settings.json (no secrets).
  # License key is read from /run/agenix/flow-icons-license if present.
  home.activation.vscodiumSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _base="$HOME/nixos-config/dotfiles/vscodium/settings.json"
    _target="$HOME/.config/VSCodium/User/settings.json"
    _license="/run/agenix/flow-icons-license"

    # Remove any existing symlink so we can write a real file
    [ -L "$_target" ] && rm "$_target"

    if [ -r "$_license" ]; then
      ${pkgs.python3}/bin/python3 -c "
import json, sys
with open('$_base') as f:
    s = json.load(f)
with open('$_license') as f:
    s['flow-icons.licenseKey'] = f.read().strip()
with open('$_target', 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
"
    else
      cp "$_base" "$_target"
    fi
  '';

  # =========================================================================
  # SSH agent
  # =========================================================================
  services.ssh-agent.enable = true;

  # =========================================================================
  # Hytale — auto-install + overrides (see modules/home/hytale.nix)
  # =========================================================================
  programs.hytale = {
    enable      = true;
    cdnFallback = true;  # Download from CDN if local bundle not found
  };

  home.activation.obsidianVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/Obsidian"
  '';

  # =========================================================================
  # VSCodium — Claude Code NixOS wrapper
  #
  # The Claude Code extension bundles a generic Linux binary that can't run
  # on NixOS (dynamic linker mismatch). This activation script replaces the
  # bundled binary with a thin wrapper that calls the Nix-installed claude.
  #
  # Runs on every rebuild so it survives extension updates automatically.
  # The original binary is preserved as claude.orig on first run.
  # =========================================================================
  home.activation.vscodiumClaudeWrapper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CLAUDE_REAL="/etc/profiles/per-user/${config.home.username}/bin/claude"
    EXT_DIR="$HOME/.vscode-oss/extensions"

    for ext_claude in "$EXT_DIR"/anthropic.claude-code-*/resources/native-binary/claude; do
      [ -e "$ext_claude" ] || continue
      # Skip Nix store paths — read-only; claudeProcessWrapper in settings.json handles NixOS
      case "$ext_claude" in /nix/store/*) continue;; esac
      # Skip if already our wrapper
      grep -q "exec $CLAUDE_REAL" "$ext_claude" 2>/dev/null && continue
      # Backup original binary once
      [ -f "$ext_claude.orig" ] || mv "$ext_claude" "$ext_claude.orig"
      [ -f "$ext_claude.orig" ] && rm -f "$ext_claude"
      printf '#!/bin/sh\nexec %s "$@"\n' "$CLAUDE_REAL" > "$ext_claude"
      chmod +x "$ext_claude"
    done
  '';

  # Seed MangoWC config on first install.
  # After this point matugen owns ~/.config/mango/config.conf and regenerates
  # it on every wallpaper change (see wallpaper-slideshow.nix [templates.mangowc]).
  # We only copy if the file is absent so we don't stomp live matugen output.
  home.activation.mangowcConfigSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _mangowc_conf="$HOME/.config/mango/config.conf"
    if [ ! -f "$_mangowc_conf" ]; then
      mkdir -p "$(dirname "$_mangowc_conf")"
      cp "${../../dotfiles/mangowc/config.conf}" "$_mangowc_conf"
      chmod 644 "$_mangowc_conf"
    fi
  '';

  # hypridle — symlink the profile config into the .config/hypr directory.
  # Since .config/hypr is a directory symlink to dotfiles/hypr/, we can't use
  # home.file here. activation runs after writeBoundary and handles it cleanly.
  # The symlink created here is gitignored (see .gitignore: dotfiles/hypr/hypridle.conf).
  home.activation.hypridleConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ln -sf "$HOME/nixos-config/dotfiles/hypr/hypridle-${hypridleProfile}.conf" \
           "$HOME/nixos-config/dotfiles/hypr/hypridle.conf"
  '';

  # Personal packages live in modules/users/linuxury-packages.nix
}
