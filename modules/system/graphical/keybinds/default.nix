# ===========================================================================
# modules/system/graphical/keybinds/default.nix — Shared terminal keybinds
#
# Declares the standard terminal keybinds for every graphical host,
# regardless of which DE/WM is active. This is the canonical source of truth
# for keybind parity across all desktops:
#
#   SUPER+Return       → kitty (tiled)
#   SUPER+SHIFT+Return → kitty --class floating-term (floating quick terminal)
#
# DE coverage:
#   Hyprland — dotfiles/hypr/modules/keybinds.lua (managed in dotfile; Hyprland's
#              Lua config is a dotfile, not a NixOS/HM module)
#   COSMIC   — RON files in ~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/
#   KDE      — kglobalshortcutsrc (appended via home.activation; must be
#              writable because KDE modifies it at runtime — no symlinks)
#   GNOME    — dconf org/gnome/settings-daemon/plugins/media-keys custom keybindings
#   Niri     — programs.niri.settings.binds in compositors/niri/default.nix sharedModules
#              (programs.niri HM option only exists when NixOS niri module is enabled,
#              so it cannot be set here safely)
#
# Files written for inactive DEs are harmless — they are simply never read.
# This makes adding or switching DEs on any host a zero-extra-config operation.
#
# Foundation for the Universal Keybind Viewer (pending): all binds will live
# here so the viewer can source a single module for the complete keybind map.
# ===========================================================================

{ lib, pkgs, ... }:

{
  # =========================================================================
  # COSMIC shortcuts
  #
  # COSMIC merges custom/ on top of its built-in defaults — only overrides
  # need to be listed. system_actions maps System(Terminal) (SUPER+T default)
  # to kitty so that shortcut is also consistent.
  # =========================================================================
  home.file.".config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom" = {
    force = true;
    text = ''
      {
          (modifiers: [Super], key: "Return"): Spawn("kitty"),
          (modifiers: [Super, Shift], key: "Return"): Spawn("kitty --class floating-term"),
      }
    '';
  };

  home.file.".config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/system_actions" = {
    force = true;
    text = ''
      {
          Terminal: "kitty",
      }
    '';
  };

  # =========================================================================
  # KDE shortcuts
  #
  # kitty-floating needs a .desktop entry so KDE can register it as a
  # shortcut target. NoDisplay=true keeps it out of the app launcher.
  #
  # kglobalshortcutsrc is writable at runtime (KDE edits it via System
  # Settings) so home.file / xdg.configFile would create a read-only symlink
  # that silently blocks KDE's writes. Instead, home.activation appends only
  # the kitty sections if absent, leaving all other user shortcuts intact.
  # =========================================================================
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

  home.activation.kdeCloseWindowShortcut = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file "$HOME/.config/kglobalshortcutsrc" \
      --group kwin \
      --key "Window Close" $'Meta+Q\tAlt+F4,Alt+F4,Close Window'
  '';

  home.activation.kdeKittyShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    KGLOBAL="$HOME/.config/kglobalshortcutsrc"
    if ! grep -q '^\[kitty\.desktop\]' "$KGLOBAL" 2>/dev/null; then
      printf '\n[kitty.desktop]\n_k_friendly_name=kitty\n_launch=Meta+Return,none,kitty\n' >> "$KGLOBAL"
    fi
    if ! grep -q '^\[kitty-floating\.desktop\]' "$KGLOBAL" 2>/dev/null; then
      printf '\n[kitty-floating.desktop]\n_k_friendly_name=kitty (floating)\n_launch=Meta+Shift+Return,none,kitty (floating)\n' >> "$KGLOBAL"
    fi
  '';

  # =========================================================================
  # GNOME shortcuts
  #
  # GNOME uses dconf for keybindings. Custom app-launch shortcuts are stored
  # as numbered entries under custom-keybindings. The list at the parent key
  # must enumerate every active custom binding path.
  # =========================================================================
  dconf.settings = {
    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" ];
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name    = "kitty";
      command = "kitty";
      binding = "<Super>Return";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      name    = "kitty (floating)";
      command = "kitty --class floating-term";
      binding = "<Super><Shift>Return";
    };
  };

}
