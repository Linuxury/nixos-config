# ===========================================================================
# modules/shells/noctalia/default.nix — Noctalia shell layer
#
# Quickshell-based desktop shell: bar, launcher, notifications, widgets.
# Originally paired with MangoWC but works on any wlr-layer-shell compositor.
#
# Binary cache: noctalia.cachix.org — avoids recompiling Qt/Quickshell (~30m).
#
# Importing this module activates Noctalia. No enable flag needed.
# Noctalia does not provide a login screen — add greeters/sddm to your host.
#
# To switch shell: remove this import, add shells/dms or shells/wayle.
# ===========================================================================

{ pkgs, ... }:

{
  # =========================================================================
  # Binary cache — pre-built Noctalia + Quickshell binaries
  # Without this, the first build recompiles Qt from source (~30 min).
  # =========================================================================
  nix.settings = {
    extra-substituters      = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  # =========================================================================
  # Packages — shell layer + Quickshell toolkit
  # =========================================================================
  environment.systemPackages = with pkgs; [
    noctalia-shell   # Shell layer: bar, launcher, notifications, widgets
    noctalia-qs      # Quickshell-based QtQuick toolkit used by noctalia-shell
  ];

  # =========================================================================
  # Home Manager — color sync + Hyprland shell-active.conf + wallpaper hook
  # =========================================================================
  home-manager.sharedModules = [

    # Patch ~/.config/noctalia/settings.json to wire the wallpaperChange hook.
    # The hook writes the current wallpaper path to ~/.local/share/current-wallpaper,
    # which triggers the matugen path unit and keeps SDDM in sync.
    #
    # $1 is string-replaced (not a shell var) with the wallpaper path by Noctalia
    # before passing the command to sh -lc, so single-quoting it handles spaces.
    # hooks.enabled must be true — Noctalia skips all hooks if it is false.
    ({ pkgs, lib, ... }: {
      home.activation.noctaliaHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _settings="$HOME/.config/noctalia/settings.json"
        if [ -f "$_settings" ]; then
          ${pkgs.python3}/bin/python3 - "$_settings" << 'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    s = json.load(f)
h = s.setdefault("hooks", {})
hook_cmd = "printf '%s\\n' '$1' > $HOME/.local/share/current-wallpaper"
changed = not h.get("enabled") or h.get("wallpaperChange") != hook_cmd
if changed:
    h["enabled"] = True
    h["wallpaperChange"] = hook_cmd
    with open(path, "w") as f:
        json.dump(s, f, indent=2)
    print("noctalia: wallpaper hook configured")
PYEOF
        fi
      '';
    })

    # Sync MangoWC focus border color with Noctalia's active accent (mPrimary).
    # Path unit watches ~/.config/noctalia/colors.json for changes.
    # Safe on non-MangoWC compositors — the mmsg call exits cleanly if
    # MangoWC is not running.
    ./color-sync/default.nix

    # Clear shell-active.lua — Noctalia does not need Hyprland config
    # overrides (it manages its own layer via wlr-layer-shell directly).
    ({ lib, ... }: {
      home.activation.shellActiveConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/nixos-config/dotfiles/hypr/shell-active.lua"
        [ -d "$(dirname "$_target")" ] || exit 0
        : > "$_target"
      '';
    })

    # Import Noctalia's generated color CSS into GTK4.
    # Noctalia writes ~/.config/gtk-4.0/noctalia.css on each launch with
    # the current accent colors. Importing it here makes GTK4 apps pick up
    # the Noctalia palette without any manual CSS edits.
    {
      gtk.gtk4.extraCss = ''@import url("noctalia.css");'';
    }

    # Write shell-autostart.lua — Noctalia has no systemd service so it
    # must be launched via exec-once. hyprland.lua dofile()s this file.
    ({ lib, ... }: {
      home.activation.shellAutostartConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/nixos-config/dotfiles/hypr/shell-autostart.lua"
        [ -d "$(dirname "$_target")" ] || exit 0
        printf '%s\n' \
          'hl.on("hyprland.start", function()' \
          '    hl.exec_cmd("noctalia-shell")' \
          'end)' \
          > "$_target"
      '';
    })

  ];
}
