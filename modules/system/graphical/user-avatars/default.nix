# ===========================================================================
# modules/system/graphical/user-avatars/default.nix — user avatar setup
#
# Writes avatar icons to two locations so every greeter can find them:
#
#   1. /var/lib/sddm-faces/${username}.face.icon
#      SDDM's native FacesDir lookup — no accountsservice needed.
#      NixOS builds SDDM without libaccountsservice, so this is the only
#      path SDDM's UserModel actually reads.  The sddm module sets FacesDir
#      to this directory.  Extension must end in .face.icon so SDDM finds
#      it, and hypr-sddm's QML regex (patched to accept .icon) loads it.
#
#   2. /var/lib/AccountsService/icons/${username}.${ext}
#      AccountsService — used by cosmic-greeter, gdm, and any D-Bus client
#      querying org.freedesktop.Accounts.User.IconFile.
#
# Avatar source layout (Avatar/ in the Assets input, flake input "assets"):
#   linuxury.jpg     → linuxury
#   babylinux.jpeg   → babylinux
#   alexander.jpg    → alex
#
# Paths point directly into the Assets input rather than through the
# HM-managed ~/Pictures/Avatar symlink.  NixOS system activationScripts run
# BEFORE HM user activations — on the first rebuild the ~/Pictures/Avatar
# symlink does not exist yet, so [ -f ] tests against that path fail silently
# and no icons are ever written.  The input is a store path, so it is always
# there and nothing needs cloning first.
# The [ -f ] guard below skips users that have no avatar file.
#
# Imported by: modules/system/graphical/default.nix
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

let
  # Map each username to their avatar in the Assets flake input.
  # Reading the input directly avoids the HM-symlink timing race described
  # in the header comment above.
  avatarMap = {
    linuxury  = "${inputs.assets}/Avatar/linuxury.jpg";
    babylinux = "${inputs.assets}/Avatar/babylinux.jpeg";
    alex      = "${inputs.assets}/Avatar/alexander.jpg";
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
      mkdir -p /var/lib/sddm-faces
      chmod 755 /var/lib/sddm-faces
      mkdir -p /var/lib/AccountsService/icons /var/lib/AccountsService/users

      ${lib.concatStrings (lib.mapAttrsToList (username: avatarPath:
        let ext  = lib.last (lib.splitString "." (builtins.baseNameOf avatarPath));
            # SDDM FacesDir: looks for ${username}.face.icon (no accountsservice needed)
            sddm = "/var/lib/sddm-faces/${username}.face.icon";
            # AccountsService: for cosmic-greeter, gdm, D-Bus clients
            acct = "/var/lib/AccountsService/icons/${username}.${ext}";
        in ''
        if [ -f "${avatarPath}" ]; then
          cp "${avatarPath}" "${sddm}"
          chmod 644 "${sddm}"
          cp "${avatarPath}" "${acct}"
          chmod 644 "${acct}"
          printf '[User]\nIcon=${acct}\nSystemAccount=false\n' \
            > "/var/lib/AccountsService/users/${username}"
          chmod 644 "/var/lib/AccountsService/users/${username}"
        fi
      '') activeUsers)}
    '';
  };
}
