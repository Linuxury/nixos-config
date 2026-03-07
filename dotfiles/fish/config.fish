# Ensure NixOS setuid wrappers always take priority — nix shells can displace them
fish_add_path --prepend /run/wrappers/bin

# Default editor — Helix for both terminal and "visual" contexts.
# Most tools check VISUAL first, then fall back to EDITOR.
set -gx EDITOR hx
set -gx VISUAL hx

if status is-interactive
    set -g fish_greeting ""

    # System info on startup
    fastfetch

    # Prompt
    starship init fish | source

    # Smarter cd
    zoxide init fish | source

    # ---------------------------------------------------------------------------
    # NixOS management aliases
    #
    # Config lives at ~/nixos-config (symlinked from /etc/nixos).
    # The hostname is picked up automatically from the flake.
    # ---------------------------------------------------------------------------

    # Rebuild and apply the current config (daily driver)
    # systemd-inhibit prevents idle-suspend from killing the build if the
    # terminal crashes mid-way (e.g. during a kernel-inclusive switch)
    alias nr 'sudo systemd-inhibit --what=sleep:idle --who=nixos-rebuild --why="NixOS rebuild in progress" nixos-rebuild switch --flake ~/nixos-config --print-build-logs'

    # Rebuild + update nixpkgs flake input before switching
    alias nru 'sudo systemd-inhibit --what=sleep:idle --who=nixos-rebuild --why="NixOS rebuild in progress" nixos-rebuild switch --flake ~/nixos-config --update-input nixpkgs --print-build-logs'

    # Set next boot target — use for kernel or bootloader changes
    alias nrb 'sudo nixos-rebuild boot --flake ~/nixos-config --print-build-logs'

    # Test build without activating — catches errors safely
    alias nrt 'sudo nixos-rebuild test --flake ~/nixos-config --print-build-logs'

    # Roll back to the previous generation
    alias nrr 'sudo nixos-rebuild switch --rollback'

    # Garbage collect — removes generations older than 30 days
    alias ngc 'sudo nix-collect-garbage --delete-older-than 30d'

    # List all system generations
    alias ngens 'sudo nix-env --list-generations --profile /nix/var/nix/profiles/system'

    # ---------------------------------------------------------------------------
    # agenix secret management
    #
    # agenix looks for secrets.nix in the CURRENT directory, so we use
    # env -C to run from ~/nixos-config/secrets/ without changing the shell's cwd.
    # Usage: age-edit description-linuxury.age  (filename only, no path prefix)
    # ---------------------------------------------------------------------------

    # Edit or create a secret (pass just the .age filename, no path prefix)
    alias age-edit 'env -C ~/nixos-config/secrets nix run github:ryantm/agenix -- -e'

    # Re-key all secrets after adding a new host to secrets/secrets.nix
    alias age-rekey 'env -C ~/nixos-config/secrets nix run github:ryantm/agenix -- -r'

    # ---------------------------------------------------------------------------
    # Snapper snapshot management
    # ---------------------------------------------------------------------------

    alias snaps 'sudo snapper -c root list' # list system snapshots
    alias snapsh 'sudo snapper -c home list' # list home snapshots
    alias snapc 'sudo snapper -c root create --description' # create manual snapshot

end
