# ===========================================================================
# modules/system/graphical/user-avatars.nix — AccountsService user avatars
#
# Sets user avatar icons via AccountsService so they appear in the greeter
# (dms-greeter, cosmic-greeter) and any other AccountsService-aware tool.
#
# Each user has ~/Pictures/Avatar symlinked to their own nixos-config clone
# (managed by Home Manager). Using per-user paths means this works on all
# hosts — linuxury has no home on babylinux/alex machines so a shared path
# would silently fail there.
#
# Avatar source layout (~/Pictures/Avatar/ per user):
#   linuxury.jpg     → linuxury
#   babylinux.jpeg   → babylinux
#   alexander.jpg    → alex
#
# Imported by: modules/system/graphical/default.nix
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  # Map each username to its avatar file in their own ~/Pictures/Avatar/
  avatarMap = {
    linuxury  = "/home/linuxury/Pictures/Avatar/linuxury.jpg";
    babylinux = "/home/babylinux/Pictures/Avatar/babylinux.jpeg";
    alex      = "/home/alex/Pictures/Avatar/alexander.jpg";
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
