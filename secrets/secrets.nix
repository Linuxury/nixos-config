# ===========================================================================
# secrets/secrets.nix — Declares which SSH public keys can decrypt each secret
#
# HOW AGENIX WORKS:
#   Each .age file in this directory is encrypted for a set of recipients.
#   A recipient is an SSH public key. The corresponding private key (either
#   your personal key or a host's SSH host key) decrypts the secret.
#
# TWO TYPES OF RECIPIENTS:
#   1. linuxury-personal   — your personal SSH key (so you can re-encrypt
#                            secrets when rotating keys or adding new hosts)
#   2. <hostname>          — each machine's SSH host key (generated at first boot)
#                            so the machine can decrypt its own secrets
#
# SETUP STEPS:
#   1. Paste your personal public key below (cat ~/.ssh/id_ed25519.pub)
#   2. After installing each host for the first time, collect its host key:
#        ssh-keyscan -t ed25519 <hostname-or-ip>
#      Paste the key string (without "hostname" prefix) for that host below.
#   3. Re-encrypt all secrets for the new host:
#        nix run nixpkgs#agenix -- -r
#
# CREATING A SECRET:
#   nix run nixpkgs#agenix -- -e secrets/mysecret.age
#   (Opens $EDITOR. Type the secret, save, close.)
#
# The encrypted .age files are safe to commit — only holders of the
# corresponding private keys can decrypt them.
# ===========================================================================

let

  # Deduplicate a list — prevents ragenix errors when placeholder host keys
  # are identical to a personal key already in linuxury-admins.
  # Replace placeholder keys with real host keys after first boot:
  #   ssh-keyscan -t ed25519 <hostname-or-ip> | awk '{print $2 " " $3}'
  uniq = builtins.foldl'
    (acc: x: if builtins.elem x acc then acc else acc ++ [ x ]) [];

  # --------------------------------------------------------------------------
  # PERSONAL SSH KEYS (per-machine — each can re-key secrets independently)
  #
  # Add a new entry when setting up a new machine:
  #   cat ~/.ssh/id_ed25519.pub
  # --------------------------------------------------------------------------
  linuxury-personal    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  thinkpad-personal    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILx6aZyKXvPNCP9q+Mv+5FLJ/G3O7IA8duJuTkxeB6Uz linuxury-thinkpad";
  ryzen5900x-personal  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7VayUjJnywEEhyLOnc5E4Pqb5DxoNDmVVNLRpiV7dQ ryzen5900x-linuxury";

  linuxury-admins = [ linuxury-personal thinkpad-personal ryzen5900x-personal ];

  # --------------------------------------------------------------------------
  # HOST SSH HOST KEYS
  #
  # Collect after first boot of each host:
  #   ssh-keyscan -t ed25519 <hostname-or-ip> | awk '{print $3}'
  #
  # Format: "ssh-ed25519 <key-data>"
  # --------------------------------------------------------------------------
  ThinkPad     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIT5rYiAs2ukQJtUmGWTD5nbxX74fh3vG3OyNxE1XfdJ root@ThinkPad";
  Ryzen5900x   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHyps7MacHDkQcGP1kr6ZOc6fR/JTMrj4my3Bg5ybyJo root@Ryzen5900x";
  Ryzen5800x   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  Asus-A15     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  Alex-Desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  Alex-Laptop  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILyHn+dSmJU01t4p81PfmhHb8yaRjUhoarvQwTDJQ69T root@Alex-Laptop";
  MinisForum   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  Radxa-X4     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBE88V1jx/3qtbt94uueOdch+E+NEyIZ0JqIFYFRaEz";
  Media-Server          = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICY9WqgrApfNR85yBAilUncMSVwnaatj9obAkmG7jSm/ root@Media-Server";
  media-server-personal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJYO2Wc9utl/dH/8y6CB6s6gfGIsOMGOq7DwFxcR4G1I Media-Server-linuxury";

  # --------------------------------------------------------------------------
  # Convenience groups
  # --------------------------------------------------------------------------
  linuxury-machines = [ ThinkPad Ryzen5900x MinisForum Radxa-X4 Media-Server ];
  babylinux-machines = [ Ryzen5800x Asus-A15 ];
  alex-machines = [ Alex-Desktop Alex-Laptop ];

in {

  # --------------------------------------------------------------------------
  # linuxury's SSH authorized key
  #
  # The .age file contains linuxury's SSH PUBLIC key (authorized_keys format).
  # agenix decrypts it onto each host so linuxury can SSH in after install.
  # Deployed to: all hosts where linuxury has a user account.
  # --------------------------------------------------------------------------
  "linuxury-authorized-key.age".publicKeys = uniq (
    linuxury-admins ++ linuxury-machines ++ babylinux-machines ++ alex-machines);

  # --------------------------------------------------------------------------
  # WireGuard config for qBittorrent VPN killswitch
  #
  # Contains the PRIVATE key + peer config (wg-quick format).
  # NEVER commit the decrypted version. Only the .age file belongs here.
  # Moved from babylinux machines to Radxa-X4 (dedicated torrent host).
  # After updating: nix run nixpkgs#agenix -- -r
  # --------------------------------------------------------------------------
  "wireguard-vpnunlimited.age".publicKeys = uniq (
    linuxury-admins ++ [ Radxa-X4 ]);

  # --------------------------------------------------------------------------
  # User display names (GECOS / full names)
  #
  # These secrets are set via activation scripts so nixos-rebuild does not
  # reset the GECOS field to blank on every switch.
  #
  # Machines with placeholder host keys (babylinux/alex) should only import
  # the corresponding module after real host keys are collected and re-keyed.
  # --------------------------------------------------------------------------
  "description-linuxury.age".publicKeys = uniq (
    linuxury-admins ++ [ ThinkPad Ryzen5900x ]);

  "description-babylinux.age".publicKeys = uniq (
    linuxury-admins ++ babylinux-machines);

  "description-alex.age".publicKeys = uniq (
    linuxury-admins ++ alex-machines);

  # --------------------------------------------------------------------------
  # Samba credentials for mounting Media-Server share
  # Deployed to all COSMIC hosts — each mounts /mnt/Media-Server in their
  # fileSystems config. Authenticates as linuxury; uid/gid set per host.
  #
  # After updating this list, re-encrypt with:
  #   nix run nixpkgs#agenix -- -r
  # --------------------------------------------------------------------------
  "smb-credentials.age".publicKeys = uniq (
    linuxury-admins ++ [ ThinkPad Ryzen5900x Radxa-X4 MinisForum ] ++ babylinux-machines ++ alex-machines);

  # --------------------------------------------------------------------------
  # FreshRSS admin password
  #
  # Plain text password for the FreshRSS admin account (linuxury).
  # Migrated from Radxa-X4 to Media-Server.
  # After updating: nix run nixpkgs#agenix -- -r
  # --------------------------------------------------------------------------
  "freshrss-admin-password.age".publicKeys = uniq (
    linuxury-admins ++ [ Media-Server ]);

}
