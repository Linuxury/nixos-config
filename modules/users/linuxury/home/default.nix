# ===========================================================================
# modules/users/linuxury/home/default.nix — Home Manager config for linuxury
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
  lib,
  inputs,
  wallpaperDir,
  hypridleProfile,
  ...
}:

{
  imports = [
    ../../../../modules/system/graphical/hytale/default.nix
    ../../../../modules/users/wallpapers/default.nix
    ../../../../modules/system/graphical/nautilus/default.nix
    ../../../../modules/system/graphical/thunar/default.nix
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
  # GUI apps launched from Hyprland run inside a systemd user session whose
  # PATH comes from environment.d configs, not from shell profiles.
  # Without this, apps like Zed can't find binaries installed via
  # Home Manager (e.g. claude-code, nil, nixfmt).
  #
  # home.sessionPath writes to ~/.config/environment.d/ which systemd user
  # sessions read automatically — no shell involved.
  # =========================================================================
  home.sessionPath = [
    "/run/wrappers/bin"
    "/etc/profiles/per-user/linuxury/bin"
    "/run/current-system/sw/bin"
  ];

  # =========================================================================
  # Default app env vars
  #
  # Some apps (scripts, Claude Code, file managers' "Open Terminal Here",
  # language runtimes, etc.) use $BROWSER/$TERMINAL instead of xdg-open.
  # home.sessionVariables writes to ~/.config/environment.d/ so every
  # app in the systemd user session inherits them — not just shell children.
  # =========================================================================
  home.sessionVariables = {
    BROWSER  = "zen-beta";
    TERMINAL = "kitty";
  };

  # =========================================================================
  # GSettings default apps — GNOME apps check this instead of mimeapps.list
  #
  # Nautilus "Open Terminal Here" reads terminal.exec from GSettings, not
  # mimeapps.list. The schema default is xdg-terminal-exec which is not
  # installed, so "Open Terminal Here" silently fails. Set kitty directly.
  # =========================================================================
  dconf.settings = {
    "org/gnome/desktop/default-applications/terminal" = {
      exec     = "kitty";
      exec-arg = "--";
    };
  };

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
    # Starship prompt — deployed via home.activation.starshipSeed below
    # (copy-once, not a symlink) so Noctalia's native app-theming can patch
    # the live file. See modules/shells/noctalia/default.nix for why.

    # Fastfetch
    ".config/fastfetch".source = "${inputs.zsh}/fastfetch";

    # Topgrade — NixOS flake version
    ".config/topgrade.toml".source = ../../../../dotfiles/topgrade/topgrade-nixos.toml;

    # MangoHud — performance overlay for gaming
    ".config/MangoHud".source = ../../../../dotfiles/MangoHud;

    # Kitty terminal — deployed via home.activation.kittyConfSeed below
    # (copy-once, not a symlink) so Noctalia's native app-theming can patch
    # the live file with its own color include. See
    # modules/shells/noctalia/default.nix for why.

    # Hyprland — full config directory (entry point + all modules)
    # Live symlink so edits in the repo take effect immediately via hyprctl reload
    ".config/hypr".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/hypr";

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

    # Pi (pi-acp, used via Zed's agent_servers) reads its global instructions
    # from ~/.pi/agent/AGENTS.md at startup — same shared rules file as the
    # top-level ~/AGENTS.md, so Pi follows the same conventions as Claude
    # Agent and opencode when run as a Zed external agent.
    ".pi/agent/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/Shared/AGENTS.md";


    # Wayle desktop shell — static config (runtime.toml stores GUI/CLI overrides)
    ".config/wayle/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/wayle/config.toml";

    # Nano — for quick root edits
    ".nanorc".source = ../../../../dotfiles/nano/.nanorc;

    # -----------------------------------------------------------------------
    # ~/Pictures/Wallpapers is a writable folder, filled from the Assets input
    # by modules/users/wallpapers (wallpaperDir is passed per-host from
    # flake.nix: ThinkPad "4k", Ryzen5900x "3440x1440"). The slideshow reads it.
    #
    # Picture assets — symlinked from the Assets input into ~/Pictures/
    #
    # This puts all family photos and game art where the DE and image
    # viewer can discover them naturally, without a detour through the store.
    # -----------------------------------------------------------------------

    # ~/Pictures/Avatar → <assets>/Avatar (family profile photos)
    "Pictures/Avatar".source =
      "${inputs.assets}/Avatar";

    # ~/.face.icon — SDDM reads this as the primary user avatar.  Points
    # directly to the repo asset (not through ~/Pictures/Avatar) so it exists
    # even before ~/Pictures/Avatar is symlinked on first HM activation.
    ".face.icon".source =
      "${inputs.assets}/Avatar/linuxury.jpg";

    # ~/Pictures/Minecraft → <assets>/Minecraft (skins, packs art)
    "Pictures/Minecraft".source =
      "${inputs.assets}/Minecraft";

    # ~/Pictures/SteamGridDB → <assets>/SteamGridDB (Steam cover art)
    "Pictures/SteamGridDB".source =
      "${inputs.assets}/SteamGridDB";

    # ~/Pictures/Fastfetch → <assets>/Fastfetch/linuxury (per-user image pool)
    "Pictures/Fastfetch".source =
      "${inputs.assets}/Fastfetch/linuxury";

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

      # babylinux's machines: log in as her (nru, her repo, her shell); my key
      # is in babylinux-authorized-key.age. `ssh linuxury@<host>` for my sudo.
      Host ryzen5800x
        HostName     Ryzen5800x
        User         babylinux
        IdentityFile ~/.ssh/id_ed25519

      Host asus-a15
        HostName     Asus-A15
        User         babylinux
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

  # Remove manually-created AI symlinks/files so home-manager can take ownership.
  # Safe to run repeatedly — only acts on symlinks or plain files, never dirs.
  # Remove the old mimeapps.list location so it never diverges from the
  # HM-managed ~/.config/mimeapps.list. Apps that call `xdg-mime default`
  # write here (old spec location), but ~/.config/mimeapps.list takes
  # precedence. Having both risks apps reading conflicting data over time.
  home.activation.cleanupOldMimeApps = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f "$HOME/.local/share/applications/mimeapps.list"
  '';

  home.activation.migrateAiSymlinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # Clean up top-level symlinks/files so HM can recreate them
    for f in \
      "$HOME/AGENTS.md" \
      "$HOME/CLAUDE.md" \
      "$HOME/.config/opencode/opencode.json" \
      "$HOME/.claude.json" \
      "$HOME/.pi/agent/AGENTS.md"; do
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

        # Jarvis vault
        notes = "cd ~/Jarvis && nvim .";

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
    initContent = import "${inputs.zsh}/init.nix" { inherit lib; };
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

  # VSCodium Claude wrapper — moved to modules/development/editors/vscodium/hm.nix

  # hypridle — symlink the profile config into the .config/hypr directory.
  # Since .config/hypr is a directory symlink to dotfiles/hypr/, we can't use
  # home.file here. activation runs after writeBoundary and handles it cleanly.
  # The symlink created here is gitignored (see .gitignore: dotfiles/hypr/hypridle.conf).
  home.activation.hypridleConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ln -sf "$HOME/nixos-config/dotfiles/hypr/hypridle-${hypridleProfile}.conf" \
           "$HOME/nixos-config/dotfiles/hypr/hypridle.conf"
  '';

  # Kitty + starship — copy-once instead of a symlink, so Noctalia's native
  # app-theming (enabled in its own settings.json, see
  # modules/shells/noctalia/default.nix) can patch the live file and reload
  # the app. A Nix-store symlink blocks that write silently — see this
  # session's investigation for the full story. Only seeds on first run;
  # Nix never touches these files again afterward.
  home.activation.kittyConfSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _cfg="$HOME/.config/kitty/kitty.conf"
    _template="$HOME/nixos-config/dotfiles/kitty/kitty.conf"
    mkdir -p "$HOME/.config/kitty"
    # First run after switching away from the old HM-managed symlink: remove
    # the stale symlink so the [ ! -f ] check below actually re-seeds a real
    # file instead of seeing the (still-resolving) old symlink and skipping.
    [ -L "$_cfg" ] && rm -f "$_cfg"
    if [ ! -f "$_cfg" ] && [ -f "$_template" ]; then
      cp "$_template" "$_cfg"
    fi
  '';

  home.activation.starshipSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _cfg="$HOME/.config/starship.toml"
    _template="${inputs.zsh}/starship/starship.toml"
    [ -L "$_cfg" ] && rm -f "$_cfg"
    if [ ! -f "$_cfg" ] && [ -f "$_template" ]; then
      cp "$_template" "$_cfg"
      # The template is a read-only store path; matugen must be able to overwrite the copy.
      chmod u+w "$_cfg"
    fi
  '';

  # Millennium (programs.steam.millennium.enable) — seed-once, same reason as
  # kitty above: Millennium rewrites config.json and noctalia writes
  # matugen.css into the theme dir, so these must be real writable files.
  # Refresh the snapshot after changing settings in Steam:
  #   cp ~/.config/millennium/{config.json,quick.css} ~/nixos-config/dotfiles/millennium/
  # steam-easygrid is deliberately absent — it crashed the UI (React #130).
  home.activation.millenniumSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] (let
    materialTheme = pkgs.fetchFromGitHub {
      owner = "kuska1";
      repo = "Material-Theme";
      rev = "f91b4e9cbc5436f149e6b293391a9a96ab47fbe9";
      hash = "sha256-qPzo59NyKsmKkhupOf3n9X29p/Wbv7jaKDGaM23HTJo=";
    };
  in ''
    _src="$HOME/nixos-config/dotfiles/millennium"
    if [ -d "$_src" ]; then
      mkdir -p "$HOME/.config/millennium" "$HOME/.local/share/millennium/plugins"
      [ -f "$HOME/.config/millennium/config.json" ] || cp "$_src/config.json" "$HOME/.config/millennium/"
      for _p in "$_src"/plugins/*; do
        [ -d "$HOME/.local/share/millennium/plugins/$(basename "$_p")" ] || cp -r "$_p" "$HOME/.local/share/millennium/plugins/"
      done
    fi
    _skin="$HOME/.local/share/Steam/steamui/skins/Material-Theme"
    if [ ! -f "$_skin/skin.json" ]; then
      mkdir -p "$_skin"
      cp -rn --no-preserve=mode ${materialTheme}/. "$_skin/"
    fi
    # JetBrainsMono font via Millennium's Quick CSS — Material-Theme's own
    # "Font: Custom" (customFont.css) never applied. Millennium creates a
    # comment-only quick.css on first run, so seed unless ours is already in.
    # ponytail: clobbers other hand-added quick.css rules lacking "JetBrains"; keep them in dotfiles copy.
    if [ -f "$_src/quick.css" ] && ! grep -q JetBrains "$HOME/.config/millennium/quick.css" 2>/dev/null; then
      mkdir -p "$HOME/.config/millennium"
      cp "$_src/quick.css" "$HOME/.config/millennium/"
    fi
  '');

  # Firefox userChrome.css activation now lives in
  # modules/system/graphical/firefox/default.nix (home-manager.sharedModules)
  # so it applies to every user, not just linuxury.

  # Personal packages live in modules/users/linuxury-packages.nix
}
