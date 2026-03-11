# ===========================================================================
# modules/base/server-shell.nix — Zsh config for headless servers
#
# Provides the same NixOS aliases as desktop hosts (nr, nru, nrb, etc.)
# and the same quality-of-life tools (zoxide, fzf, direnv) configured at
# the NixOS system level (no Home Manager on servers).
#
# Desktop-only tools intentionally excluded:
#   - fastfetch   (graphical eye candy — not useful over SSH)
#   - starship    (prompt — servers use the default zsh prompt)
#   - snapper     (BTRFS snapshots — servers don't import snapper.nix)
#   - zsh-abbr    (overkill for servers — plain aliases used instead)
#
# Writes to /etc/zsh/ (system-level), so it applies to ALL users on the
# machine without needing Home Manager.
#
# Import this in: Radxa-X4, MinisForum, Media-Server (any headless host).
# ===========================================================================

{ lib, ... }:

{
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

  programs.zsh = {
    enable = true;
    autosuggestions.enable   = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      # Rebuild and apply the current config
      nr    = "sudo nixos-rebuild switch --flake ~/nixos-config --print-build-logs";

      # Set next boot target — use for kernel or bootloader changes
      nrb   = "sudo nixos-rebuild boot --flake ~/nixos-config --print-build-logs";

      # Test build without activating — catches errors safely
      nrt   = "sudo nixos-rebuild test --flake ~/nixos-config --print-build-logs";

      # Roll back to the previous generation
      nrr   = "sudo nixos-rebuild switch --rollback";

      # Garbage collect — removes generations older than 30 days
      ngc   = "sudo nix-collect-garbage --delete-older-than 30d";

      # List all system generations
      ngens = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";

      # agenix secret management — run from secrets/ dir (secrets.nix lives there)
      age-edit  = "nix run github:ryantm/agenix -- -e";
      age-rekey = "nix run github:ryantm/agenix -- -r";
    };

    interactiveShellInit = ''
      # Ensure NixOS setuid wrappers always take priority
      typeset -U path
      path=(/run/wrappers/bin $path)

      # Default editor
      export EDITOR=hx
      export VISUAL=hx

      # Canonical path to the nixos-config repo
      export NIXOS_CONFIG=$HOME/nixos-config

      # Rebuild + update nixpkgs flake input before switching
      nru() {
        echo "→ Pulling latest changes from $NIXOS_CONFIG..."
        git -C "$NIXOS_CONFIG" pull || return 1
        sudo nixos-rebuild switch --flake "$NIXOS_CONFIG" --update-input nixpkgs --print-build-logs
      }
    '';
  };
}
