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
    ../../modules/home/neovim.nix
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
  # XDG MIME type associations
  #
  # Tells the desktop environment which app opens each file type.
  # Without this, audio files open in whatever the DE guesses (often nothing).
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

  # mimeapps.list may already exist from a previous manual edit — allow HM
  # to take ownership so the xdg.mimeApps declarations above take effect.
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
    # Development workspace
    "d ${config.home.homeDirectory}/Projects              0755 linuxury users -"
    "d ${config.home.homeDirectory}/Projects/Python       0755 linuxury users -"
    "d ${config.home.homeDirectory}/Projects/Rust         0755 linuxury users -"
    "d ${config.home.homeDirectory}/Projects/Nix          0755 linuxury users -"
    "d ${config.home.homeDirectory}/Projects/Scripts      0755 linuxury users -"

    # Hytale flatpak bundle storage (moved out of ~/assets into ~/Documents)
    # linuxury's Hytale service reads the bundle from here before falling
    # back to the CDN download. Move the file here if you pre-downloaded it.
    "d ${config.home.homeDirectory}/Documents/assets          0755 linuxury users -"
    "d ${config.home.homeDirectory}/Documents/assets/flatpaks 0755 linuxury users -"

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

    # Hyprland — full config directory (entry point + all modules)
    # Live symlink so edits in the repo take effect immediately via hyprctl reload
    ".config/hypr".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/dotfiles/hypr";

    # Waybar — symlink config and style individually so matugen can write
    # colors.css freely into ~/.config/waybar/ without polluting the repo.
    ".config/waybar/config.jsonc".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/dotfiles/hypr/waybar/config.jsonc";
    ".config/waybar/style.css".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/dotfiles/hypr/waybar/style.css";

    # Wofi — full directory (no matugen writes here)
    ".config/wofi".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/dotfiles/hypr/wofi";

    # Swaync — symlink config and style individually (same reason as waybar)
    ".config/swaync/config.json".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/dotfiles/hypr/swaync/config.json";
    ".config/swaync/style.css".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/dotfiles/hypr/swaync/style.css";

    # Zed editor
    ".config/zed/settings.json".source = ../../dotfiles/zed/settings.json;

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

    # -----------------------------------------------------------------------
    # Picture assets — symlinked from nixos-config/assets/ into ~/Pictures/
    #
    # This puts all family photos and game art where the DE and image
    # viewer can discover them naturally, without a detour through ~/assets/.
    # -----------------------------------------------------------------------

    # ~/Pictures/Avatar → nixos-config/assets/Avatar (family profile photos)
    "Pictures/Avatar".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/assets/Avatar";

    # ~/Pictures/Minecraft → nixos-config/assets/Minecraft (skins, packs art)
    "Pictures/Minecraft".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/assets/Minecraft";

    # ~/Pictures/SteamGridDB → nixos-config/assets/SteamGridDB (Steam cover art)
    "Pictures/SteamGridDB".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/assets/SteamGridDB";

    # ~/Pictures/Fastfetch → nixos-config/assets/Fastfetch (fastfetch logo images)
    "Pictures/Fastfetch".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/assets/Fastfetch";

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

  # Remove old plain directories so home-manager can create symlinks.
  # Previous layout had ~/assets/Avatar as a tmpfiles dir; now it's a symlink
  # at ~/Pictures/Avatar. Same for Minecraft and SteamGridDB.
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
    enable            = true;
    autosuggestion.enable = true;
    enableCompletion  = true;

    # fast-syntax-highlighting — richer colors and faster than zsh-syntax-highlighting
    plugins = [
      {
        name = "fast-syntax-highlighting";
        src  = pkgs.zsh-fast-syntax-highlighting;
        file = "share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh";
      }
    ];

    # Abbreviations expand inline before running — you see the full command first.
    # Managed declaratively by Home Manager via programs.zsh.zsh-abbr.
    zsh-abbr = {
      enable = true;
      abbreviations = {
        # NixOS management
        # nr/nrb/nrt are shell functions in zshrc (run silently like nru)
        nrr   = "sudo nixos-rebuild switch --rollback";
        ngc   = "sudo nix-collect-garbage --delete-older-than 30d";
        ngens = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";

        # agenix — run from secrets/ dir without changing shell's cwd
        age-edit  = "env -C ~/nixos-config/secrets nix run github:ryantm/agenix -- -e";
        age-rekey = "env -C ~/nixos-config/secrets nix run github:ryantm/agenix -- -r";

        # Obsidian notes
        notes = "cd ~/Obsidian && nvim .";

        # Snapper snapshot management
        snaps  = "sudo snapper -c root list";
        snapsh = "sudo snapper -c home list";
        snapc  = "sudo snapper -c root create --description";
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
    enable    = true;
    settings = {
      user.name  = "Linuxury";
      user.email = "linuxurypr@gmail.com";
      init.defaultBranch = "main";
      pull.rebase        = false;
      core.editor        = "nvim";
      alias = {
        st  = "status";
        co  = "checkout";
        br  = "branch";
        lg  = "log --oneline --graph --decorate";
      };
    };
  };

  # Neovim config is now managed by the normie-nvim activation script in
  # modules/home/neovim.nix — no overrides needed here.

  # Desktop entry — opens Neovim in Kitty
  xdg.desktopEntries.nvim = {
    name        = "Neovim";
    genericName = "Text Editor";
    comment     = "Hyperextensible Vim-based text editor";
    exec        = "kitty nvim %F";
    terminal    = false;
    categories  = [ "Utility" "TextEditor" ];
    icon        = "nvim";
    mimeType    = [
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
  # SSH agent
  # =========================================================================
  services.ssh-agent.enable = true;

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
        FLATPAK_FILE="$HOME/Documents/assets/flatpaks/hytale-launcher-latest.flatpak"
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
        # Bundle location: ~/Documents/assets/flatpaks/hytale-launcher-latest.flatpak
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

        # Remove the sideload origin remote — it has no appstream data and
        # causes COSMIC Store's flatpak-user backend to fail on load.
        # The installed app is unaffected; updates re-run this service.
        $FLATPAK remote-delete --user --force hytalelauncher-origin 2>/dev/null || true

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
home.activation.obsidianVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/Obsidian"
  '';

home.activation.hytale-wayland-fix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.flatpak}/bin/flatpak override --user \
      --env=ELECTRON_OZONE_PLATFORM_HINT=x11 \
      com.hytale.Hytale 2>/dev/null || true
  '';

  # Personal packages live in modules/users/linuxury-packages.nix
}
