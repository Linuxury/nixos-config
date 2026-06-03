# ===========================================================================
# modules/development/languages/python/default.nix — Python development stack
#
# Provides a self-contained Python environment with commonly used dev packages
# bundled via python3.withPackages. This avoids the global-install conflicts
# that occur when packages are installed with pip into the system Python.
#
# Includes:
#   pip       — package installer (for virtual environments / one-off installs)
#   black     — opinionated code formatter
#   pylint    — linter, catches errors and bad practices
#   mypy      — static type checker
#   requests  — HTTP client library, essential for API work
#   rich      — beautiful terminal output (tables, progress bars, tracebacks)
#   pydantic  — data validation with type annotations
#   ipython   — enhanced REPL with tab completion, history, and magic commands
#
# Project management:
#   poetry    — dependency management and packaging (pyproject.toml based)
#   ruff      — extremely fast linter written in Rust, replaces flake8/isort
#   httpie    — friendly HTTP client for API testing from the terminal
#
# Note: pyright (LSP) lives in editors/neovim/hm.nix since it is an editor
# concern, not a language runtime concern.
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [

    # -----------------------------------------------------------------------
    # Python interpreter — bundled with dev packages for a clean environment
    # -----------------------------------------------------------------------
    (python3.withPackages (ps: with ps; [
      pip       # package installer — for venvs and one-off installs
      black     # code formatter — deterministic, no config needed
      pylint    # linter — catches errors and code quality issues
      mypy      # static type checker — catches type bugs before running
      requests  # HTTP library — fetching data, calling APIs
      rich      # terminal output — colors, tables, progress bars
      pydantic  # data validation — essential for FastAPI and config parsing
      ipython   # enhanced REPL — tab completion, history, magic commands
    ]))

    # -----------------------------------------------------------------------
    # Python tooling — outside the bundled environment
    # -----------------------------------------------------------------------
    poetry   # project + dependency manager (pyproject.toml)
    ruff     # fast linter in Rust — replaces flake8, isort, pyupgrade
    httpie   # friendly HTTP client for API testing from the terminal

  ];
}
