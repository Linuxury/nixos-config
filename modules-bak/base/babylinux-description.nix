# ===========================================================================
# modules/base/babylinux-description.nix — Set babylinux's display name via agenix
#
# Same pattern as linuxury-description.nix — decrypts the real name at
# activation time and applies it with usermod after the users script.
#
# Imported by: Ryzen5800x, Asus-A15
# NOTE: Only import after real SSH host keys are collected for these machines
#       and secrets/description-babylinux.age has been re-keyed to include them.
# Secret: secrets/description-babylinux.age
# ===========================================================================

{ config, pkgs, ... }:

{
  age.secrets.description-babylinux = {
    file = ../../secrets/description-babylinux.age;
  };

  system.activationScripts.babylinux-description = {
    deps = [ "agenix" "users" ];
    text = ''
      ${pkgs.shadow}/bin/usermod \
        --comment "$(cat ${config.age.secrets.description-babylinux.path})" \
        babylinux
    '';
  };
}
