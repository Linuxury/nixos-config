# ===========================================================================
# modules/base/user-avatars.nix — AccountsService user avatars
#
# Sets user avatar icons via AccountsService so they appear in the greeter
# (dms-greeter, cosmic-greeter) and any other AccountsService-aware tool.
#
# All avatars live in linuxury's ~/Pictures/Avatar/ — which is a symlink to
# nixos-config/assets/Avatar and is accessible on every graphical host since
# linuxury has an account everywhere. The activation script only processes
# users that actually exist on the current host.
#
# Avatar source layout:
#   /home/linuxury/Pictures/Avatar/linuxury.jpg     → linuxury
#   /home/linuxury/Pictures/Avatar/babylinux.jpeg   → babylinux
#   /home/linuxury/Pictures/Avatar/alexander.jpg    → alex
#
# Imported by: modules/base/graphical-base.nix
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  avatarBase = "/home/linuxury/Pictures/Avatar";

  # Map each username to its avatar file
  avatarMap = {
    linuxury  = "${avatarBase}/linuxury.jpg";
    babylinux = "${avatarBase}/babylinux.jpeg";
    alex      = "${avatarBase}/alexander.jpg";
  };

  # Only act on users that are defined as normal users on this host
  activeUsers = lib.filterAttrs
    (name: _:
      config.users.users ? ${name} &&
      config.users.users.${name}.isNormalUser)
    avatarMap;

in
{
  services.accounts-daemon.enable = true;

  system.activationScripts.user-avatars = {
    text = ''
      mkdir -p /var/lib/AccountsService/icons /var/lib/AccountsService/users

      ${lib.concatStrings (lib.mapAttrsToList (username: avatarPath: ''
        if [ -f "${avatarPath}" ]; then
          cp "${avatarPath}" "/var/lib/AccountsService/icons/${username}"
          chmod 644 "/var/lib/AccountsService/icons/${username}"
          printf '[User]\nIcon=/var/lib/AccountsService/icons/${username}\nSystemAccount=false\n' \
            > "/var/lib/AccountsService/users/${username}"
          chmod 644 "/var/lib/AccountsService/users/${username}"
        fi
      '') activeUsers)}
    '';
  };
}
