# ===========================================================================
# modules/users/babylinux/ssh/default.nix — Deploy babylinux's SSH authorized key
#
# Import this into every host where babylinux is the primary user.
# Mirrors linuxury/ssh/default.nix — same mechanism, different key.
#
# The encrypted secret lives at: secrets/babylinux-authorized-key.age
# At activation it decrypts to:  /etc/ssh/authorized_keys.d/babylinux
#
# Imported by: Ryzen5800x, Asus-A15
# ===========================================================================

{ ... }:

{
  age.secrets.babylinux-authorized-key = {
    file = ../../../../secrets/babylinux-authorized-key.age;
    path = "/etc/ssh/authorized_keys.d/babylinux";
    mode = "0444";
  };
}
