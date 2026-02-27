# ===========================================================================
# modules/development/development.nix — Development environment
#
# This module sets up Python and Rust development tools system-wide.
# It's designed as a starting point — as you learn and grow you'll
# naturally know what to add or change here.
#
# Enable this module only on YOUR machines (linuxury).
# Wife and kid don't need development tools.
# ===========================================================================

{ config, pkgs, ... }:

{
  # =========================================================================
  # Python
  #
  # We install Python 3 with a curated set of commonly used tools.
  # Rather than installing packages globally (which can cause conflicts),
  # we use python3.withPackages to create a self-contained Python
  # environment with everything bundled together cleanly.
  # =========================================================================
  environment.systemPackages = with pkgs; [

    # -----------------------------------------------------------------------
    # Python — with commonly used packages bundled in
    # -----------------------------------------------------------------------
    (python3.withPackages (ps: with ps; [
      # Package management
      pip           # Python package installer — you'll use this constantly

      # Code quality
      black         # Opinionated code formatter — auto-formats your code
      pylint        # Code linter — catches errors and bad practices
      mypy          # Static type checker — helps catch bugs before running

      # Useful standard libraries
      requests      # HTTP requests — fetching web data, calling APIs
      rich          # Beautiful terminal output — great for learning projects
      pydantic      # Data validation — very useful once you get deeper

      # Interactive development
      ipython       # Enhanced Python shell with tab completion and history
                    # Much nicer than the default python REPL for learning
    ]))

    # -----------------------------------------------------------------------
    # Python tooling outside of the Python environment
    # -----------------------------------------------------------------------
    poetry          # Modern Python project and dependency manager
                    # Better than pip for managing real projects
    ruff            # Extremely fast Python linter written in Rust
                    # Use alongside pylint or as a replacement

    # -----------------------------------------------------------------------
    # Rust — via rustup
    #
    # rustup is the official Rust toolchain manager. It lets you install
    # and switch between stable, beta, and nightly Rust versions easily.
    #
    # On first use run: rustup default stable
    # This installs the stable Rust compiler and cargo (Rust's package manager)
    # -----------------------------------------------------------------------
    rustup

    # -----------------------------------------------------------------------
    # Rust companion tools
    # -----------------------------------------------------------------------
    cargo-watch     # Re-runs cargo commands on file changes — great for learning
                    # Usage: cargo watch -x run
    cargo-edit      # Adds `cargo add`, `cargo rm` commands for managing
                    # dependencies without manually editing Cargo.toml
    cargo-expand    # Shows what Rust macros expand to — very useful for
                    # understanding what's happening under the hood

    # -----------------------------------------------------------------------
    # Shared tools — useful for both languages
    # -----------------------------------------------------------------------
    git             # Already in common.nix but called out here as essential
                    # for any development workflow
    just            # Command runner — like make but simpler and more readable
                    # Great for project scripts in both Python and Rust

    # Editors
    zed-editor      # Fast, Wayland-native editor written in Rust
                    # Built-in LSP support — nil + nixfmt-rfc-style wire up automatically

    # Language server + formatter support
    nil             # Nix language server — gives you autocomplete and error
                    # checking when editing your NixOS config files
    nixfmt-rfc-style # Nix code formatter — keeps your config files tidy

    # -----------------------------------------------------------------------
    # Terminal and shell tools useful during development
    # -----------------------------------------------------------------------
    jq              # Query and pretty-print JSON from the terminal
                    # You'll use this constantly when working with APIs
    httpie          # Friendlier alternative to curl for testing HTTP/APIs
    fd              # Fast modern alternative to the `find` command
    ripgrep         # Extremely fast code search (grep replacement)
                    # Usage: rg "search term" — searches recursively
  ];

  # =========================================================================
  # Environment variables
  #
  # These tell tools where to find each other and configure behavior.
  # =========================================================================
  environment.variables = {
    # Tell rustup where to install toolchains.
    # Keeps Rust installations in a consistent, predictable location.
    RUSTUP_HOME = "$HOME/.rustup";
    CARGO_HOME  = "$HOME/.cargo";

    # Add cargo's bin directory to PATH so compiled tools are accessible.
    # After `rustup default stable`, commands like `rustc` and `cargo`
    # will be found automatically.
    PATH = [ "$HOME/.cargo/bin" ];
  };

  # =========================================================================
  # Shell integration
  #
  # Makes development tools available in your shell sessions.
  # direnv watches for .envrc files in project directories and
  # automatically loads/unloads environment variables when you cd in/out.
  #
  # This pairs really well with nix develop for per-project environments —
  # you cd into a project and the right tools activate automatically.
  # =========================================================================
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true; # Optimized direnv integration for Nix flakes
  };
}
