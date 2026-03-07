# Ensure NixOS setuid wrappers always take priority — nix shells can displace them
fish_add_path --prepend /run/wrappers/bin

# Default editor
set -gx EDITOR hx
set -gx VISUAL hx

if status is-interactive
    set -g fish_greeting ""

    # ---------------------------------------------------------------------------
    # NixOS management aliases
    #
    # Config lives at ~/nixos-config (symlinked from /etc/nixos).
    # The hostname is picked up automatically from the flake.
    # ---------------------------------------------------------------------------

    # Rebuild and apply the current config (daily driver)
    alias nr 'sudo nixos-rebuild switch --flake ~/nixos-config --print-build-logs'

    # Rebuild + update nixpkgs flake input before switching
    alias nru 'sudo nixos-rebuild switch --flake ~/nixos-config --update-input nixpkgs --print-build-logs'

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
    # ---------------------------------------------------------------------------

    # Edit or create a secret (type the .age filename after)
    alias age-edit 'nix run github:ryantm/agenix -- -e'

    # Re-key all secrets after adding a new host to secrets/secrets.nix
    alias age-rekey 'nix run github:ryantm/agenix -- -r'

end
