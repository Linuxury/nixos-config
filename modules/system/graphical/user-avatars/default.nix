# ===========================================================================
# modules/system/graphical/user-avatars/default.nix — AccountsService user avatars
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

      ${lib.concatStrings (lib.mapAttrsToList (username: avatarPath:
        # Compute extension at Nix eval time so the bash script gets a plain
        # literal. This avoids ${...} bash expansions inside Nix '' strings.
        # Preserving the extension matters: hypr-sddm checks the icon path
        # against /\.(jpg|jpeg|png|bmp|webp|svg)$/i before displaying it.
        let ext = lib.last (lib.splitString "." (builtins.baseNameOf avatarPath));
            dest = "/var/lib/AccountsService/icons/${username}.${ext}";
        in ''
        if [ -f "${avatarPath}" ]; then
          cp "${avatarPath}" "${dest}"
          chmod 644 "${dest}"
          printf '[User]\nIcon=${dest}\nSystemAccount=false\n' \
            > "/var/lib/AccountsService/users/${username}"
          chmod 644 "/var/lib/AccountsService/users/${username}"
        fi
      '') activeUsers)}
    '';
  };
}
