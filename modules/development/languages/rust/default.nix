# ===========================================================================
# modules/development/languages/rust/default.nix — Rust development stack
#
# Uses rustup, the official Rust toolchain manager, rather than a fixed Nix
# package. This lets you install stable/beta/nightly and switch between them
# freely without a rebuild.
#
# First-time setup after rebuild:
#   rustup default stable   — installs stable compiler + cargo
#
# Companion tools:
#   cargo-watch   — re-runs cargo commands on file changes (cargo watch -x run)
#   cargo-edit    — adds `cargo add` / `cargo rm` for Cargo.toml management
#   cargo-expand  — shows what macros expand to (great for learning)
#   just          — command runner (like make, but readable) — popular in
#                   Rust projects for scripting build/test/deploy tasks
#
# Environment:
#   RUSTUP_HOME   — where rustup stores toolchains (~/.rustup)
#   CARGO_HOME    — where cargo stores caches and installed binaries (~/.cargo)
#   PATH          — ~/.cargo/bin added so compiled tools are accessible
# ===========================================================================

{ pkgs, ... }:

{
  # =========================================================================
  # Rust toolchain + companion tools
  # =========================================================================
  environment.systemPackages = with pkgs; [
    rustup       # official Rust toolchain manager — run `rustup default stable` first

    cargo-watch  # re-run cargo commands on file save: cargo watch -x run
    cargo-edit   # adds cargo add / cargo rm commands for Cargo.toml
    cargo-expand # show macro expansions — useful for understanding proc macros

    just         # command runner — readable alternative to make, popular in Rust projects
  ];

  # =========================================================================
  # Environment — toolchain and binary paths
  # =========================================================================
  environment.variables = {
    RUSTUP_HOME = "$HOME/.rustup";  # toolchain storage
    CARGO_HOME  = "$HOME/.cargo";   # build cache + installed binaries
    PATH        = [ "$HOME/.cargo/bin" ];  # makes `cargo install`-ed tools accessible
  };
}
