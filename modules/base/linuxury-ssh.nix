# ===========================================================================
# modules/base/linuxury-ssh.nix — Deploy linuxury's SSH authorized key
#
# Import this into every host where linuxury needs SSH access.
# It uses agenix to decrypt linuxury's public key and places it where
# OpenSSH expects it, without storing the key content in the repo.
#
# The encrypted secret lives at: secrets/linuxury-authorized-key.age
# At activation it decrypts to:  /etc/ssh/authorized_keys.d/linuxury
#
# NixOS's sshd reads /etc/ssh/authorized_keys.d/%u by default, so no
# extra sshd_config changes are needed.
#
# Imported by: ThinkPad, Ryzen5900x, MinisForum, Radxa-X4, Media-Server
#
# SETUP — before first nixos-install on a new host:
#   1. Create secrets/linuxury-authorized-key.age (if not already):
#        nix run nixpkgs#agenix -- -e secrets/linuxury-authorized-key.age
#      Paste the output of: cat ~/.ssh/id_ed25519.pub
#   2. After first boot, collect the host key and add it to secrets/secrets.nix,
#      then re-key: nix run nixpkgs#agenix -- -r
# ===========================================================================

{ config, ... }:

{
  age.secrets.linuxury-authorized-key = {
    # The encrypted public key — decrypted at activation by the host's SSH key
    file = ../../secrets/linuxury-authorized-key.age;

    # Decrypt directly into the directory sshd reads for authorized keys.
    # This path is managed by NixOS's openssh module — files here are valid
    # authorized keys for the user matching the filename.
    path = "/etc/ssh/authorized_keys.d/linuxury";

    # A public key is not a secret — world-readable is fine and required
    # so the sshd daemon (which may drop privs) can read it.
    mode = "0444";
  };
}
