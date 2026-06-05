# ===========================================================================
# modules/system/graphical/user-avatars/default.nix — AccountsService user avatars
#
# Sets user avatar icons via AccountsService so they appear in the greeter
# (sddm, cosmic-greeter) and any other AccountsService-aware tool.
#
# Avatar source layout (nixos-config/assets/Avatar/ per user):
#   linuxury.jpg     → linuxury
#   babylinux.jpeg   → babylinux
#   alexander.jpg    → alex
#
# Paths point directly to nixos-config/assets/Avatar/ rather than through
# the HM-managed ~/Pictures/Avatar symlink.  NixOS system activationScripts
# run BEFORE HM user activations — on the first rebuild the ~/Pictures/Avatar
# symlink does not exist yet, so [ -f ] tests against that path fail silently
# and no icons are ever written.  The direct repo path is always present as
# long as the nixos-config repo is cloned (a prerequisite for rebuilding).
# The [ -f ] guard below handles hosts where a given user has no repo clone.
#
# Imported by: modules/system/graphical/default.nix
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  # Map each username to their avatar in the nixos-config assets directory.
  # Using the direct repo path avoids the HM-symlink timing race described
  # in the header comment above.
  avatarMap = {
    linuxury  = "/home/linuxury/nixos-config/assets/Avatar/linuxury.jpg";
    babylinux = "/home/babylinux/nixos-config/assets/Avatar/babylinux.jpeg";
    alex      = "/home/alex/nixos-config/assets/Avatar/alexander.jpg";
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
