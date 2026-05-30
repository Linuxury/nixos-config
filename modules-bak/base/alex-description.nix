# ===========================================================================
# modules/base/alex-description.nix — Set alex's display name via agenix
#
# Same pattern as linuxury-description.nix — decrypts the real name at
# activation time and applies it with usermod after the users script.
#
# Imported by: Alex-Desktop, Alex-Laptop
# NOTE: Only import after real SSH host keys are collected for these machines
#       and secrets/description-alex.age has been re-keyed to include them.
# Secret: secrets/description-alex.age
# ===========================================================================

{ config, pkgs, ... }:

{
  age.secrets.description-alex = {
    file = ../../secrets/description-alex.age;
  };

  system.activationScripts.alex-description = {
    deps = [ "agenix" "users" ];
    text = ''
      ${pkgs.shadow}/bin/usermod \
        --comment "$(cat ${config.age.secrets.description-alex.path})" \
        alex
    '';
  };
}
