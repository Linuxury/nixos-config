# ===========================================================================
# modules/users/linuxury-packages.nix — System packages for linuxury
#
# Imported by: ThinkPad, Ryzen5900x
# ===========================================================================

{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [

    # Office
    onlyoffice-desktopeditors  # Word/Excel/PowerPoint compatible office suite

    # Shell tools
    topgrade    # One-command updater — Nix, cargo, flatpaks, etc.

    # File management
    bat         # cat with syntax highlighting and line numbers

    # Development helpers
    lazygit     # TUI for git — stage, commit, branch all in one
    gh          # GitHub CLI — PRs, issues from terminal
    delta       # Pretty diff viewer — integrates with git

    # System monitoring
    dust        # Visual disk usage — like du but readable
    procs       # Modern ps replacement with color and filtering

    # Networking
    whois       # Domain registration lookup
    traceroute  # Trace network path to a host

    # Notes
    obsidian    # Markdown-based knowledge base / note-taking app

    # Communication
    thunderbird # Email client — personal use

    # Internet
    fluent-reader # RSS feed reader — clean GTK app for following news/blogs
    obs-studio    # Screen recording and streaming

    # Misc utilities
    p7zip              # Extract .7z, .rar, and many other archive formats
    imagemagick        # CLI image conversion and manipulation
    nix-output-monitor # Progress bar + TUI for nix builds (nom)

    # Design
    # Affinity v3 (Photo + Designer + Publisher) via Wine — free, no native Linux build.
    # First run opens a graphical installer — leave the path at default.
    # Data lands at ~/.local/share/affinity-v3/
    # To update the app itself: affinity-v3 update
    inputs.affinity-nix.packages.x86_64-linux.v3

  ];
}
