# ===========================================================================
# modules/home/neovim.nix — Neovim via normie-nvim (TheBlackDon)
#
# Uses normie-nvim from GitLab as a flake input (flake = false).
# The entire ~/.config/nvim is symlinked to the flake input, so the
# config is always what's in the repo at the pinned commit.
#
# Plugins: managed by lazy.nvim — downloads to ~/.local/share/nvim/lazy/
#          on first launch. Mason is present but not used for installs
#          on NixOS (binaries below go on PATH instead).
#
# To update to TheBlackDon's latest:
#   nix flake update normie-nvim && nr
# ===========================================================================

{ inputs, pkgs, ... }:

{
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;
    # No plugins here — lazy.nvim handles them from the config
  };

  # normie-nvim config — symlinked from the flake input (read-only Nix store).
  # lazy.nvim writes plugin data to ~/.local/share/nvim/lazy/ which is
  # writable, so plugin installs/updates work fine.
  xdg.configFile."nvim" = {
    source = inputs.normie-nvim;
    force  = true;   # replaces the old HM-managed nvim/init.lua + nvim/lua symlinks
  };

  # =========================================================================
  # LSP binaries — normie-nvim's lua/servers/ calls vim.lsp.enable() which
  # looks for binaries on PATH. These Nix packages provide them, so Mason
  # doesn't need to install anything on NixOS.
  # =========================================================================
  home.packages = with pkgs; [
    # Nix
    nil                            # nil_ls
    alejandra                      # formatter (conform.lua)

    # Lua
    lua-language-server            # lua_ls
    stylua                         # formatter (conform.lua)

    # Shell
    bash-language-server           # bashls

    # Web
    vscode-langservers-extracted   # cssls + htmlls
    nodePackages.typescript-language-server  # ts_ls

    # Python
    pyright

    # Telescope backends
    fd
    ripgrep
  ];
}
