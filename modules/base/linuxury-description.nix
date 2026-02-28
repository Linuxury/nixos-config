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
}
