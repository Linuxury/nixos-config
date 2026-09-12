# ===========================================================================
# modules/system/graphical/thunar/default.nix — Thunar as default file manager
#
# Linuxury-specific: overrides the shared inode/directory default (Nautilus,
# set in modules/system/graphical/default.nix's home-manager.sharedModules)
# for this user only. Import only from users/linuxury/home.nix, not from
# home-manager.sharedModules — other hosts don't have Thunar installed.
#
# Bookmarks aren't duplicated here — Thunar reads the same
# ~/.config/gtk-3.0/bookmarks file Nautilus's module already writes.
#
# Custom Actions (right-click menu) ports the three Nautilus scripts from
# modules/system/graphical/nautilus/default.nix, plus an Open Terminal Here
# using kitty. %f is passed as a positional arg ("$1", not inlined) so paths
# with spaces (e.g. "Faugus Backup") survive intact. Nix-managed like
# Nautilus's bookmarks file — if you add more actions via Thunar's own
# "Configure custom actions" dialog later, they won't persist past the next
# rebuild; add them here instead.
# ===========================================================================

{ lib, ... }:

{
  xdg.mimeApps.defaultApplications."inode/directory" = lib.mkForce "thunar.desktop";

  home.file.".config/Thunar/uca.xml" = {
    force = true; # Thunar creates a default uca.xml on first launch; override it
    text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <actions>
      <action>
        <icon>utilities-terminal</icon>
        <name>Open Terminal Here</name>
        <unique-id>1-thunar-uca</unique-id>
        <command>kitty -d "%f"</command>
        <description>Open a kitty terminal in this location</description>
        <patterns>*</patterns>
        <directories/>
      </action>
      <action>
        <icon>edit-copy</icon>
        <name>Copy Name</name>
        <unique-id>2-thunar-uca</unique-id>
        <command>bash -c &apos;basename "$1" | tr -d "\n" | wl-copy&apos; -- "%f"</command>
        <description>Copy just the filename (no directory) to the clipboard</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      <action>
        <icon>edit-copy</icon>
        <name>Copy Path</name>
        <unique-id>3-thunar-uca</unique-id>
        <command>bash -c &apos;printf %s "$1" | wl-copy&apos; -- "%f"</command>
        <description>Copy the full path of the selected file to the clipboard</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      <action>
        <icon>system-run</icon>
        <name>Open as Root</name>
        <unique-id>4-thunar-uca</unique-id>
        <command>pkexec thunar "%f"</command>
        <description>Open the selected folder in Thunar with root privileges via pkexec</description>
        <patterns>*</patterns>
        <directories/>
      </action>
    </actions>
    '';
  };
}
