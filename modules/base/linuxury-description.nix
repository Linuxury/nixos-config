# ===========================================================================
# modules/base/linuxury-description.nix — Set linuxury's display name via agenix
#
# NixOS resets the GECOS (full name) field to blank on every nixos-rebuild
# because users.users.linuxury.description is not set in the config.
# This module decrypts the real name at activation time and applies it with
# usermod — running after both agenix (secret decrypted) and users (account
# updated) so the GECOS field is never blank after a switch.
#
# Imported by: ThinkPad, Ryzen5900x
# Secret: secrets/description-linuxury.age
# ===========================================================================

{ config, pkgs, ... }:

{
  age.secrets.description-linuxury = {
    file = ../../secrets/description-linuxury.age;
  };

  system.activationScripts.linuxury-description = {
    deps = [ "agenix" "users" ];
    text = ''
      ${pkgs.shadow}/bin/usermod \
        --comment "$(cat ${config.age.secrets.description-linuxury.path})" \
        linuxury
    '';
  };

  # AccountsService needs the avatar icon file + a user config pointing to it.
  # The source JPEG lives in the repo; we copy it on every activation so it
  # stays fresh if it ever changes. The users/ config file is only written once
  # so COSMIC Settings can still overwrite it freely.
  system.activationScripts.linuxury-greeter-avatar = {
    deps = [];
    text = ''
      AVATAR_SRC="/home/linuxury/nixos-config/assets/Avatar/linuxury.jpg"
      AVATAR_DST="/var/lib/AccountsService/icons/linuxury"
      USERS_CFG="/var/lib/AccountsService/users/linuxury"

      if [ -f "$AVATAR_SRC" ]; then
        mkdir -p /var/lib/AccountsService/icons
        ${pkgs.coreutils}/bin/cp -f "$AVATAR_SRC" "$AVATAR_DST"
        chmod 644 "$AVATAR_DST"
      fi

      mkdir -p /var/lib/AccountsService/users
      if [ ! -f "$USERS_CFG" ]; then
        printf '[User]\nIcon=%s\nSystemAccount=false\n' "$AVATAR_DST" \
          > "$USERS_CFG"
      fi
    '';
  };
}
