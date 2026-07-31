# ===========================================================================
# modules/development/editors/zed/default.nix — Zed Editor
#
# Zed is a fast, Wayland-native code editor written in Rust with built-in
# LSP support, vim mode, blurred window background, and GPU rendering.
#
# Enable per host by importing this module:
#   ../../modules/development/editors/zed/default.nix
#
# Settings portability: dotfiles/zed/settings.json holds the full baseline
# config (fonts, panels, keymap, agent setup, etc). On first activation on
# any host, if ~/.config/zed/settings.json doesn't exist yet, it's copied
# from that tracked template — so enabling this module on a new host brings
# the same setup instead of starting blank. After that first copy, the file
# is left alone (Zed writes to it directly via its Settings UI, and the key
# injection below edits it in place), so per-host drift afterward is fine —
# it just won't be clobbered back to the template on every rebuild.
#
# AI: Claude via OpenRouter (language_model_providers.openai → openrouter.ai).
# The OpenRouter key is injected from /run/agenix/openrouter-api-key at
# activation time — never stored in the Nix store. dotfiles/zed/settings.json
# ships with api_key = "" — the secret only ever lives in the live file.
# ===========================================================================

{ lib, pkgs, ... }:

{
  # Force OpenGL backend — avoids wgpu Vulkan surface panic on Hyprland workspace switch
  environment.sessionVariables.WGPU_BACKEND = "gl";

  # =========================================================================
  # Zed — system package (available to all users on this host)
  # =========================================================================
  environment.systemPackages = with pkgs; [
    zed-editor
    nixd        # Nix language server — required by Zed's Nix extension
  ];

  # Text editor MIME defaults — lib.mkForce wins over VSCodium (plain) and
  # Neovim (lib.mkDefault) when all three are installed on the same host.
  home-manager.sharedModules = [
    ({ lib, ... }: {
      xdg.mimeApps.defaultApplications = {
        "text/plain"                = lib.mkForce "dev.zed.Zed.desktop";
        "application/json"          = lib.mkForce "dev.zed.Zed.desktop";
        "application/x-yaml"        = lib.mkForce "dev.zed.Zed.desktop";
        "application/toml"          = lib.mkForce "dev.zed.Zed.desktop";
        "application/x-shellscript" = lib.mkForce "dev.zed.Zed.desktop";
        "text/x-shellscript"        = lib.mkForce "dev.zed.Zed.desktop";
      };

      # =====================================================================
      # Bootstrap ~/.config/zed/settings.json from the tracked template.
      #
      # Only fires if the file doesn't exist yet — first activation on a
      # fresh host. Existing configs (like the one already hand-tuned on
      # Ryzen5900x) are never overwritten.
      # =====================================================================
      home.activation.zedBootstrapSettings =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          _cfg="$HOME/.config/zed/settings.json"
          _template="$HOME/nixos-config/dotfiles/zed/settings.json"
          mkdir -p "$HOME/.config/zed"
          if [ ! -f "$_cfg" ] && [ -f "$_template" ]; then
            cp "$_template" "$_cfg"
          fi
          unset _cfg _template
        '';

      # =====================================================================
      # Inject OpenRouter API key into Zed's settings.json at activation time.
      #
      # Zed doesn't support environment variable expansion in settings values,
      # so jq writes the key directly into the file from the agenix runtime
      # path. Runs on every rebuild — safe to re-run (idempotent merge).
      #
      # Zed uses JSONC (JSON with comments). sed strips comment lines before
      # jq parses; the result is written back as plain JSON — Zed accepts both.
      # =====================================================================
      home.activation.zedInjectOpenRouterKey =
        lib.hm.dag.entryAfter [ "zedBootstrapSettings" ] ''
          _key_file="/run/agenix/openrouter-api-key"
          _cfg="$HOME/.config/zed/settings.json"
          if [ -r "$_key_file" ] && [ -f "$_cfg" ]; then
            _key=$(cat "$_key_file")
            _tmp=$(${pkgs.gnused}/bin/sed '/^[[:space:]]*\/\//d' "$_cfg" \
              | ${lib.getExe pkgs.jq} \
                  --arg key "$_key" \
                  '.language_model_providers.openai.api_key = $key')
            printf '%s\n' "$_tmp" > "$_cfg"
            unset _key _tmp
          fi
          unset _key_file _cfg
        '';
    })
  ];
}
