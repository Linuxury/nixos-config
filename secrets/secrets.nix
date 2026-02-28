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

  # --------------------------------------------------------------------------
  # PERSONAL SSH KEYS (per-machine — each can re-key secrets independently)
  #
  # Add a new entry when setting up a new machine:
  #   cat ~/.ssh/id_ed25519.pub
  # --------------------------------------------------------------------------
  linuxury-personal  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  thinkpad-personal  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFMI6+u1Rvq/1gkZhRheZ+LsEa+3aZ+/lTU6EV0lUCHJ linuxury-thinkpad";

  linuxury-admins = [ linuxury-personal thinkpad-personal ];

  # --------------------------------------------------------------------------
  # HOST SSH HOST KEYS
  #
  # Collect after first boot of each host:
  #   ssh-keyscan -t ed25519 <hostname-or-ip> | awk '{print $3}'
  #
  # Format: "ssh-ed25519 <key-data>"
  # --------------------------------------------------------------------------
  ThinkPad     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHEb/f6rkOOvJ/hcBQZVbHGFg/GyZOBJzPkdwejar82u root@ThinkPad";
  Ryzen5900x   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFG1gbiGRl8imkfxDr8OaGq0EPP/Q2j6zREO3VhrmZgV root@Ryzen5900x";
  Ryzen5800x   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  Asus-A15     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  Alex-Desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  Alex-Laptop  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  MinisForum   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  Radxa-X4     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";
  Media-Server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0ZEivzBqlE7mH2ZepwWmTnQM2Oha6q0Mblx20CyvcP linuxurypr@gmail.com";

  # --------------------------------------------------------------------------
  # Convenience groups
  # --------------------------------------------------------------------------
  linuxury-machines = [ ThinkPad Ryzen5900x MinisForum Radxa-X4 Media-Server ];
  babylinux-machines = [ Ryzen5800x Asus-A15 ];

in {

  # --------------------------------------------------------------------------
  # linuxury's SSH authorized key
  #
  # The .age file contains linuxury's SSH PUBLIC key (authorized_keys format).
  # agenix decrypts it onto each host so linuxury can SSH in after install.
  # Deployed to: all hosts where linuxury has a user account.
  # --------------------------------------------------------------------------
  "linuxury-authorized-key.age".publicKeys =
    linuxury-admins ++ linuxury-machines;

  # --------------------------------------------------------------------------
  # WireGuard config for qBittorrent VPN killswitch
  #
  # Contains the PRIVATE key + peer config (wg-quick format).
  # NEVER commit the decrypted version. Only the .age file belongs here.
  # Deployed to: babylinux's machines running vpn-qbittorrent.
  # --------------------------------------------------------------------------
  "wireguard-vpnunlimited.age".publicKeys =
    linuxury-admins ++ babylinux-machines;

  # --------------------------------------------------------------------------
  # FreshRSS admin password
  #
  # Plain text password for the FreshRSS admin account (linuxury).
  # Deployed to: Radxa-X4 only.
  # --------------------------------------------------------------------------
  "freshrss-admin-password.age".publicKeys =
    linuxury-admins ++ [ Radxa-X4 ];

}
