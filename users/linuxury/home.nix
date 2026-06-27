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
    ../../modules/system/graphical/hytale/default.nix
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
  # =========================================================================
  # Browser — per-user choice (shared app defaults live in graphical/default.nix)
  # =========================================================================
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http"  = "zen-beta.desktop";
    "x-scheme-handler/https" = "zen-beta.desktop";
    "text/html"              = "zen-beta.desktop";
    "application/xhtml+xml"  = "zen-beta.desktop";
  };

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

    # Zed editor — dotfile managed by modules/development/editors/zed/default.nix
    # OpenCode dotfiles — managed by modules/development/ai-tools/opencode/default.nix

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
    # opencode.json — managed by modules/development/ai-tools/opencode/default.nix
    ".claude.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/Claude/state.json";


    # Wayle desktop shell — static config (runtime.toml stores GUI/CLI overrides)
    ".config/wayle/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/wayle/config.toml";

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

    # ~/.face.icon — SDDM reads this as the primary user avatar.  Points
    # directly to the repo asset (not through ~/Pictures/Avatar) so it exists
    # even before ~/Pictures/Avatar is symlinked on first HM activation.
    ".face.icon".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/assets/Avatar/linuxury.jpg";

    # ~/Pictures/Minecraft → nixos-config/assets/Minecraft (skins, packs art)
    "Pictures/Minecraft".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/assets/Minecraft";

    # ~/Pictures/SteamGridDB → nixos-config/assets/SteamGridDB (Steam cover art)
    "Pictures/SteamGridDB".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/assets/SteamGridDB";

    # ~/Pictures/Fastfetch → nixos-config/assets/Fastfetch/linuxury (per-user image pool)
    "Pictures/Fastfetch".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/assets/Fastfetch/linuxury";

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
    # Appended: linuxury-specific management functions (hytale-update, etc.)
    initContent = (lib.fileContents ../../dotfiles/zsh/zshrc) + ''

      # -----------------------------------------------------------------------
      # hytale-update — update the Hytale game server on MinisForum over SSH
      #
      # Runs the full update sequence non-interactively:
      #   1. Stop server
      #   2. Re-download hytale-downloader (it's versioned — always update it)
      #   3. Download server.zip from CDN
      #   4. Extract and move Assets.zip into Server/
      #   5. Clear any auto-update staging dir (prevents exit-code-8 restart loop)
      #   6. Start server + print last 20 log lines
      #
      # Requires: NOPASSWD sudoers rule for hytale-server in MinisForum/default.nix
      #
      # IF STEP 3 FAILS with "oauth2: invalid_grant" (credentials expired, ~every 90 days):
      #   ssh -t MinisForum
      #   cd /data/gameservers/hytale
      #   rm .hytale-downloader-credentials.json
      #   ./hytale-downloader-linux-amd64 -download-path server.zip
      #   → follow the device auth flow (URL + code in browser)
      #   → then manually finish: unzip -o server.zip -d . && mv -f Assets.zip Server/ && rm -f server.zip
      #   → sudo systemctl start hytale-server
      #   After re-auth, hytale-update works again until next expiry.
      # -----------------------------------------------------------------------
      hytale-update() {
        echo "→ Connecting to MinisForum..."
        ssh MinisForum bash << 'ENDSSH'
          set -e
          echo "=== [1/5] Stopping Hytale server ==="
          sudo systemctl stop hytale-server

          cd /data/gameservers/hytale

          echo "=== [2/5] Updating downloader ==="
          wget -q -O hytale-downloader.zip https://downloader.hytale.com/hytale-downloader.zip
          unzip -o -q hytale-downloader.zip
          chmod +x hytale-downloader-linux-amd64
          rm -f hytale-downloader.zip

          echo "=== [3/5] Downloading server update ==="
          if ! ./hytale-downloader-linux-amd64 -download-path server.zip -skip-update-check; then
            echo ""
            echo "ERROR: Download failed. If you see 'oauth2: invalid_grant', credentials expired."
            echo "Fix: ssh -t MinisForum → rm /data/gameservers/hytale/.hytale-downloader-credentials.json"
            echo "     → run downloader manually to re-auth, then finish update manually."
            sudo systemctl start hytale-server
            exit 1
          fi

          echo "=== [4/5] Applying update ==="
          unzip -o server.zip -d .
          mv -f Assets.zip Server/
          rm -f server.zip
          rm -rf Server/update-staging 2>/dev/null || true

          echo "=== [5/5] Starting Hytale server ==="
          sudo systemctl start hytale-server

          echo ""
          echo "=== Done. Last 20 log lines: ==="
          journalctl -u hytale-server --no-pager -n 20
ENDSSH
      }
    '';
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

  # Neovim config is managed by the activation script in
  # modules/development/editors/neovim/hm.nix — no overrides needed here.

  # Neovim desktop entry and text editor MIME defaults are declared in
  # modules/system/graphical/default.nix via home-manager.sharedModules.

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

  # VSCodium — moved to modules/development/editors/vscodium/default.nix

  # =========================================================================
  # SSH agent
  # =========================================================================
  services.ssh-agent.enable = true;

  # =========================================================================
  # Hytale — auto-install + overrides (see modules/system/graphical/hytale/default.nix)
  # =========================================================================
  programs.hytale = {
    enable      = true;
    cdnFallback = true;  # Download from CDN if local bundle not found
  };

  home.activation.obsidianVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/Obsidian"
  '';

  # VSCodium Claude wrapper — moved to modules/development/editors/vscodium/hm.nix

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

  # Keep Proton-GE Latest in Steam's compat tools dir in sync with the Nix package.
  # programs.steam.extraCompatPackages adds the package to STEAM_EXTRA_COMPAT_TOOLS_PATH
  # but Steam also maintains its own copy in ~/.local/share/Steam/compatibilitytools.d/.
  # Without this, the Steam-managed copy can drift (e.g. a ProtonPlus download replaces
  # it with the wrong architecture). This activation overwrites it on every HM rebuild,
  # keeping Faugus and other non-Steam launchers pointed at the correct x86_64 build.
  home.activation.protonGeCompatTool = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _dest="$HOME/.local/share/Steam/compatibilitytools.d/Proton-GE Latest"
    _src="${pkgs.proton-ge-custom}"
    _src_ver="$(cat "$_src/version" 2>/dev/null)"
    _dst_ver="$(cat "$_dest/version" 2>/dev/null)"
    if [ "$_src_ver" != "$_dst_ver" ]; then
      rm -rf "$_dest"
      cp -r "$_src" "$_dest"
      chmod -R u+w "$_dest"
    fi
  '';

  # Personal packages live in modules/users/linuxury-packages.nix
}
