# ===========================================================================
# modules/desktops/kde/keybinds/default.nix — KDE terminal keybinds
#
# Adds parity with Hyprland:
#   SUPER+Return       → kitty (tiled)
#   SUPER+SHIFT+Return → kitty --class floating-term (floating quick terminal)
#
# kglobalshortcutsrc is a live writable INI file — KDE modifies it at runtime
# when the user changes shortcuts in System Settings. Using home.file / xdg.configFile
# would create a read-only symlink, causing silent write failures.
#
# Instead: home.activation appends only the kitty sections if absent,
# preserving all other shortcuts the user may have set.
#
# The kitty-floating desktop entry is needed because KDE's global shortcut
# system binds to .desktop entries, not raw commands.
# ===========================================================================

{ lib, ... }:

{
  # kitty-floating — desktop entry so KDE can register it as a shortcut target.
  # NoDisplay=true keeps it out of the app launcher (Kickoff/KRunner) but
  # leaves it available for global shortcuts and kglobalshortcutsrc.
  home.file.".local/share/applications/kitty-floating.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=kitty (floating)
    Comment=Floating terminal
    Exec=kitty --class floating-term
    Icon=kitty
    Categories=System;TerminalEmulator;
    NoDisplay=true
  '';

  # Append kitty shortcut entries to kglobalshortcutsrc only if not already present.
  # Format: _launch=<active shortcut>,<default shortcut>,<friendly description>
  # Setting the default to "none" means no system-wide default — only our binding.
  home.activation.kdeKittyShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    KGLOBAL="$HOME/.config/kglobalshortcutsrc"
    if ! grep -q '^\[kitty\.desktop\]' "$KGLOBAL" 2>/dev/null; then
      printf '\n[kitty.desktop]\n_k_friendly_name=kitty\n_launch=Meta+Return,none,kitty\n' >> "$KGLOBAL"
    fi
    if ! grep -q '^\[kitty-floating\.desktop\]' "$KGLOBAL" 2>/dev/null; then
      printf '\n[kitty-floating.desktop]\n_k_friendly_name=kitty (floating)\n_launch=Meta+Shift+Return,none,kitty (floating)\n' >> "$KGLOBAL"
    fi
  '';
}
