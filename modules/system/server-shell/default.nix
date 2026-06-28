# ===========================================================================
# modules/system/server-shell/default.nix — Zsh config for headless servers
#
# Provides the same shell environment as desktop hosts by sourcing the shared
# dotfiles/zsh/zshrc directly. All nru/nr/nrt functions, aliases, and
# management tooling stay in one place — changes propagate everywhere.
#
# Server-specific additions (not in zshrc):
#   - TERM fallback (silences "can't find terminal definition" on SSH login)
#   - age-edit / age-rekey aliases (desktop uses zsh-abbr; servers use aliases)
#

# Writes to /etc/zsh/ (system-level), applies to ALL users without Home Manager.
# Import in: Radxa-X4, MinisForum, Media-Server, any headless host.
# ===========================================================================

{ pkgs, lib, ... }:

{
  # SSH agent — system-level, sets SSH_AUTH_SOCK via PAM for all login shells
  programs.ssh.startAgent = true;

  # Starship — cross-shell prompt (system-level, all users)
  programs.starship.enable = true;

  # Zoxide — smarter cd (system-level, all users)
  programs.zoxide.enable = true;

  # FZF — fuzzy finder: Ctrl+R history, Ctrl+T file picker, Alt+C cd
  programs.fzf.fuzzyCompletion = true;
  programs.fzf.keybindings     = true;

  # Direnv — auto-loads .envrc on cd (nix develop shells, project env vars)
  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
  };

  # Fastfetch — system info on shell start (same as desktop)
  environment.systemPackages = [ pkgs.fastfetch ];
  environment.etc."fastfetch/config.jsonc".source = ../../../dotfiles/fastfetch/config.jsonc;

  # TERM fallback — runs in /etc/zsh/zshenv before NixOS's set-environment
  # script, silencing "can't find terminal definition" errors on SSH login.
  programs.zsh.shellInit = ''
    if [ -n "$TERM" ] && ! infocmp "$TERM" >/dev/null 2>&1; then
      export TERM=xterm-256color
    fi
  '';

  programs.zsh = {
    enable                 = true;
    autosuggestions.enable  = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      # agenix secret management — run from secrets/ dir (secrets.nix lives there).
      # Desktop hosts use zsh-abbr for these; servers use plain aliases.
      age-edit  = "nix run github:ryantm/agenix -- -e";
      age-rekey = "nix run github:ryantm/agenix -- -r";
    };

    # Shared init — same zshrc as desktop hosts.
    # lib.fileContents embeds the file content at eval time; shell ${...}
    # references are not interpreted by Nix, only by zsh at runtime.
    interactiveShellInit = lib.fileContents ../../../dotfiles/zsh/zshrc;
  };
}
