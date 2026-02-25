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
    alias nr    'sudo nixos-rebuild switch --flake ~/nixos-config'

    # Rebuild + update nixpkgs flake input before switching
    alias nru   'sudo nixos-rebuild switch --flake ~/nixos-config --update-input nixpkgs'

    # Set next boot target — use for kernel or bootloader changes
    alias nrb   'sudo nixos-rebuild boot --flake ~/nixos-config'

    # Test build without activating — catches errors safely
    alias nrt   'sudo nixos-rebuild test --flake ~/nixos-config'

    # Roll back to the previous generation
    alias nrr   'sudo nixos-rebuild switch --rollback'

    # Garbage collect — removes generations older than 30 days
    alias ngc   'sudo nix-collect-garbage --delete-older-than 30d'

    # List all system generations
    alias ngens 'sudo nix-env --list-generations --profile /nix/var/nix/profiles/system'

    # ---------------------------------------------------------------------------
    # agenix secret management
    # ---------------------------------------------------------------------------

    # Edit or create a secret (type the .age filename after)
    alias age-edit  'nix run nixpkgs#agenix -- -e'

    # Re-key all secrets after adding a new host to secrets/secrets.nix
    alias age-rekey 'nix run nixpkgs#agenix -- -r'

    # ---------------------------------------------------------------------------
    # Snapper snapshot management
    # ---------------------------------------------------------------------------

    alias snaps  'sudo snapper -c root list'             # list system snapshots
    alias snapsh 'sudo snapper -c home list'             # list home snapshots
    alias snapc  'sudo snapper -c root create --description'  # create manual snapshot

end
