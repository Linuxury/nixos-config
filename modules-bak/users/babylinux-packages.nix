# ===========================================================================
# modules/users/babylinux-packages.nix — System packages for babylinux
#
# Imported by: Ryzen5800x, Asus-A15
# ===========================================================================

{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [

    # NixOS tools
    nix-output-monitor # Progress bar + TUI for nix builds (nom)

    # Communication
    zoom-us         # Video conferencing

    # Knowledge base
    obsidian        # Markdown-based note-taking / knowledge base

    # Design
    # Affinity v3 (Photo + Designer + Publisher) via Wine — free, no native Linux build.
    # First run opens a graphical installer — leave the path at default.
    # Data lands at ~/.local/share/affinity-v3/
    # To update the app itself: affinity-v3 update
    inputs.affinity-nix.packages.x86_64-linux.v3
  ];
}
