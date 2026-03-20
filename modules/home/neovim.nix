# ===========================================================================
# modules/home/neovim.nix — Neovim via normie-nvim (TheBlackDon)
#
# Uses normie-nvim from GitLab as a flake input (flake = false).
# Instead of symlinking the Nix store path (read-only), an activation
# script rsyncs the config into a real writable directory so lazy.nvim
# can update lazy-lock.json without hitting a read-only filesystem error.
#
# Plugins: managed by lazy.nvim — downloads to ~/.local/share/nvim/lazy/
#          on first launch. Mason is present but not used for binary installs
#          on NixOS — LSP binaries below go on PATH from Nix instead.
#
# To update to TheBlackDon's latest:
#   nru   (flake update + rebuild)
# ===========================================================================

{ inputs, pkgs, lib, ... }:

{
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;
  };

  # =========================================================================
  # Sync normie-nvim config into a real writable directory
  #
  # xdg.configFile symlinks point into the read-only Nix store, which causes
  # lazy.nvim to error when it tries to update lazy-lock.json. Using rsync
  # in an activation script makes ~/.config/nvim a normal writable dir.
  #
  # On every rebuild: rsync copies changed files (fast, incremental).
  # lazy-lock.json is included so plugin versions match TheBlackDon's pinned
  # state after each update. Run :Lazy update inside nvim to go newer.
  # =========================================================================
  home.activation.normieNvim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    NVIM_DIR="$HOME/.config/nvim"

    # If a symlink exists from the old xdg.configFile approach, remove it
    if [ -L "$NVIM_DIR" ]; then
      rm "$NVIM_DIR"
    fi

    mkdir -p "$NVIM_DIR"

    ${pkgs.rsync}/bin/rsync -a --delete \
      "${inputs.normie-nvim}/" "$NVIM_DIR/"
  '';

  # =========================================================================
  # LSP binaries — normie-nvim's lua/servers/ calls vim.lsp.enable() which
  # looks for binaries on PATH. These Nix packages provide them, so Mason
  # doesn't need to install anything on NixOS.
  # =========================================================================
  home.packages = with pkgs; [
    # Nix
    nil                                      # nil_ls
    alejandra                                # formatter (conform.lua)

    # Lua
    lua-language-server                      # lua_ls
    stylua                                   # formatter (conform.lua)

    # Shell
    bash-language-server                     # bashls

    # Web
    vscode-langservers-extracted             # cssls + htmlls
    nodePackages.typescript-language-server  # ts_ls
    tailwindcss-language-server              # tailwindcss

    # Python
    pyright

    # C/C++
    clang-tools                              # clangd

    # Hyprland config
    hyprls                                   # hyprls

    # Treesitter parser compilation
    gcc

    # Telescope backends
    fd
    ripgrep
  ];
}
