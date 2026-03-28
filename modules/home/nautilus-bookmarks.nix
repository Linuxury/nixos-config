# ===========================================================================
# modules/home/nautilus-bookmarks.nix — Bookmarks and scripts for Nautilus
#
# Nautilus reads sidebar bookmarks from ~/.config/gtk-3.0/bookmarks.
# Samba shares appear as smb:// URIs — browsed via gvfs (enabled in
# graphical-base.nix with Samba support).
#
# Scripts live in ~/.local/share/nautilus/scripts/ and appear in the
# right-click context menu under Scripts.
# ===========================================================================

{ ... }:

{
  # ---------------------------------------------------------------------------
  # Sidebar bookmarks
  # ---------------------------------------------------------------------------
  home.file.".config/gtk-3.0/bookmarks".text = ''
    file:///home/linuxury/Documents Documents
    file:///home/linuxury/Downloads Downloads
    file:///home/linuxury/Music Music
    file:///home/linuxury/Pictures Pictures
    file:///home/linuxury/Videos Videos
    file:///mnt/Media-Server Media-Server
    file:///mnt/Torrents Torrents
    file:///mnt/MinisForum MinisForum
  '';

  # ---------------------------------------------------------------------------
  # Scripts — appear in right-click → Scripts menu
  # Uses wl-copy (wl-clipboard) since we're on Wayland.
  # ---------------------------------------------------------------------------
  home.file.".local/share/nautilus/scripts/Copy Path" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Copy the full path of the selected file to the Wayland clipboard.
      echo -n "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | head -1 | tr -d '\n' | wl-copy
    '';
  };

  home.file.".local/share/nautilus/scripts/Copy Name" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Copy just the filename (no directory) to the Wayland clipboard.
      echo -n "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | head -1 | xargs basename | tr -d '\n' | wl-copy
    '';
  };

  home.file.".local/share/nautilus/scripts/Open as Root" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Open the selected folder in Nautilus with root privileges via pkexec.
      # Polkit handles the password prompt (polkit_gnome is running on Hyprland).
      DIR=$(echo "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | head -1 | tr -d '\n')
      pkexec nautilus "$DIR"
    '';
  };
}
