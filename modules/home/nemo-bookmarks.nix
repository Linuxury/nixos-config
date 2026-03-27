# ===========================================================================
# modules/home/nemo-bookmarks.nix — GTK3 bookmarks for Nemo file manager
#
# Nemo reads sidebar bookmarks from ~/.config/gtk-3.0/bookmarks.
# This file is separate from cosmic-theme.nix because COSMIC uses
# its own favorites format, while Nemo (Hyprland) uses GTK3 bookmarks.
#
# Samba shares appear as smb:// URIs — Nemo browses them via gvfs
# (already enabled in graphical-base.nix with Samba support).
# ===========================================================================

{ ... }:

{
  home.file.".config/gtk-3.0/bookmarks".text = ''
    file:///home/linuxury/Documents Documents
    file:///home/linuxury/Downloads Downloads
    file:///home/linuxury/Music Music
    file:///home/linuxury/Pictures Pictures
    file:///home/linuxury/Videos Videos
    smb://Media-Server/Media-Server Media-Server
    smb://Media-Server/Downloads Downloads
    smb://MinisForum/GameServers MinisForum
  '';
}
