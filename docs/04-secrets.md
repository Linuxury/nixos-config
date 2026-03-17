# 🔐 Secrets Management

How encrypted secrets work in this config — what the tool is, how to create secrets, edit them, add machines as recipients, and re-key. This covers everything from the access control file (`secrets.nix`) to the day-to-day CLI workflow.

---

## 📋 Contents

- [The Big Picture](#the-big-picture)
- [How secrets.nix Works](#how-secretsnix-works)
- [The ragenix CLI](#the-ragenix-cli)
- [Secrets Reference](#secrets-reference)
- [Workflow: Adding a New Machine](#workflow-adding-a-new-machine)
- [Workflow: Creating a New Secret](#workflow-creating-a-new-secret)
- [Workflow: Updating an Existing Secret](#workflow-updating-an-existing-secret)
- [Where Secrets Land on Disk](#where-secrets-land-on-disk)
- [Troubleshooting](#troubleshooting)

---

## 🧠 The Big Picture

[↑ Back to Contents](#-contents)

This config uses **agenix** (via the `ryantm/agenix` flake) to manage secrets at the NixOS system level. The CLI you interact with is **ragenix** — a Rust re-implementation with the same interface.

The core idea:

- Secrets are encrypted with **age** using SSH public keys as the "lock"
- A secret file can only be decrypted by machines whose SSH keys are listed as recipients
- Encrypted `.age` files are safe to commit to the repo — no plaintext ever touches git
- At boot/activation, agenix decrypts each secret and places it at a configured path on disk

```
secrets/
├── secrets.nix                     ← Defines who can read what
├── smb-credentials.age             ← Encrypted Samba mount credentials
├── wireguard-vpnunlimited.age      ← Mullvad WireGuard config (Radxa-X4 only)
├── freshrss-admin-password.age     ← FreshRSS admin password
├── linuxury-authorized-key.age     ← linuxury's SSH public key (for authorized_keys)
└── description-*.age               ← User GECOS display names
```

---

## 🔑 How secrets.nix Works

[↑ Back to Contents](#-contents)

`secrets/secrets.nix` is the access control list. It maps each secret file to the set of SSH public keys that can decrypt it:

```nix
let
  # Host keys — these are /etc/ssh/ssh_host_ed25519_key.pub on each machine
  thinkpad-host     = "ssh-ed25519 AAAA...";
  ryzen5900x-host   = "ssh-ed25519 AAAA...";

  # Personal key — linuxury's ~/.ssh/id_ed25519.pub
  linuxury-personal = "ssh-ed25519 AAAA...";

  # Groupings for convenience
  linuxury-admins   = [ linuxury-personal ];
  all-desktop-hosts = [ thinkpad-host ryzen5900x-host ryzen5800x-host ... ];
in
{
  # This secret is readable by all desktop hosts and by linuxury (for re-keying)
  "smb-credentials.age".publicKeys = all-desktop-hosts ++ linuxury-admins;

  # This secret is readable only by Radxa-X4 and by linuxury
  "wireguard-vpnunlimited.age".publicKeys = [ radxa-host ] ++ linuxury-admins;
}
```

**Two types of keys serve different purposes:**

| Key type | Source | Used for |
|----------|--------|---------|
| Host keys | `/etc/ssh/ssh_host_ed25519_key.pub` | Decrypting at boot — the machine reads its own secret |
| Personal keys | `~/.ssh/id_ed25519.pub` | Re-keying secrets from the command line |

linuxury's personal key must always be in `linuxury-admins` — otherwise linuxury cannot re-key secrets from the admin machine.

---

## 🛠️ The ragenix CLI

[↑ Back to Contents](#-contents)

> ⚠️ The CLI is **ragenix** — use `nix run nixpkgs#ragenix`. Do not use `nix run github:ryantm/agenix`.
> ⚠️ Always run ragenix from the `secrets/` directory — it reads `secrets.nix` from the current directory.

### Create or edit a secret

Open the secret in your `$EDITOR`. Type or paste the plaintext value, save, and close — the file is encrypted automatically on save:

```bash
cd ~/nixos-config/secrets
nix run nixpkgs#ragenix -- -e secret-name.age
```

The `age-edit` abbreviation in your zsh config expands to this. You can also use:

```bash
age-edit secret-name.age   # same thing — abbreviation defined in home.nix
```

### Re-key all secrets

Re-encrypts every `.age` file with the current recipients from `secrets.nix`. Run this any time you add, remove, or update a key:

```bash
cd ~/nixos-config/secrets
nix run nixpkgs#ragenix -- -r
```

The `age-rekey` abbreviation does the same thing. Re-keying requires your personal private key (`~/.ssh/id_ed25519`) on the machine you run it from.

---

## 📋 Secrets Reference

[↑ Back to Contents](#-contents)

| File | What it contains | Who can decrypt it |
|------|-----------------|-------------------|
| `smb-credentials.age` | Samba username and password for CIFS mounts | All graphical hosts + admins |
| `wireguard-vpnunlimited.age` | Mullvad WireGuard config for qBittorrent VPN | Radxa-X4 + admins |
| `freshrss-admin-password.age` | FreshRSS admin account password | Media-Server + admins |
| `linuxury-authorized-key.age` | linuxury's SSH public key (deployed to `authorized_keys`) | All hosts + admins |
| `description-linuxury.age` | GECOS display name "Erick Rodriguez" | ThinkPad, Ryzen5900x + admins |
| `description-babylinux.age` | GECOS display name "Milagros Monserrate" | Ryzen5800x, Asus-A15 + admins |
| `description-alex.age` | GECOS display name "Alexander Rodriguez" | Alex-Desktop, Alex-Laptop + admins |

> 💡 `wireguard-vpnunlimited.age` is still named "vpnunlimited" for historical reasons — the VPN provider was changed from VPN Unlimited to Mullvad. The filename was not changed to avoid unnecessary re-keying and reference updates.

---

## ➕ Workflow: Adding a New Machine

[↑ Back to Contents](#-contents)

When you install NixOS on a new machine and want it to access secrets:

1. **Get the host's SSH public key** (on the new machine after first boot):
   ```bash
   cat /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. **On your admin machine**, open `secrets/secrets.nix` and add the key:
   ```nix
   let
     new-machine-host = "ssh-ed25519 AAAA...";   # ← paste the key here
   in
   {
     "smb-credentials.age".publicKeys = [
       # ... existing keys ...
       new-machine-host   # ← add to every secret this machine needs to read
     ];
   }
   ```

3. **Re-key:**
   ```bash
   cd ~/nixos-config/secrets
   nix run nixpkgs#ragenix -- -r
   ```

4. **Commit and push:**
   ```bash
   git add secrets/
   git commit -m "add host key for NewMachine"
   git push
   ```

5. **Rebuild on the new machine** — agenix will now successfully decrypt its secrets during activation:
   ```bash
   sudo nixos-rebuild switch --flake ~/nixos-config#NewMachine
   ```

---

## ➕ Workflow: Creating a New Secret

[↑ Back to Contents](#-contents)

1. **Add the secret to `secrets.nix`** to declare who can read it:
   ```nix
   "my-new-secret.age".publicKeys = some-machines ++ linuxury-admins;
   ```

2. **Create the encrypted file** — type the secret value in your editor, save, close:
   ```bash
   cd ~/nixos-config/secrets
   nix run nixpkgs#ragenix -- -e my-new-secret.age
   ```

3. **Reference it in a host config:**
   ```nix
   # In hosts/<HostName>/default.nix:
   age.secrets.my-new-secret.file = ../../secrets/my-new-secret.age;

   # Use the decrypted path in another option:
   environment.etc."myapp/config".source = config.age.secrets.my-new-secret.path;
   ```

4. **Commit:**
   ```bash
   git add secrets/secrets.nix secrets/my-new-secret.age
   git commit -m "add my-new-secret"
   git push
   ```

---

## 🔄 Workflow: Updating an Existing Secret

[↑ Back to Contents](#-contents)

To change a secret's value (for example, rotating the VPN config after switching Mullvad servers), open it in your editor, save the new value, commit, and rebuild any affected machines:

```bash
cd ~/nixos-config/secrets
nix run nixpkgs#ragenix -- -e wireguard-vpnunlimited.age   # edit in $EDITOR, save, close
git add wireguard-vpnunlimited.age
git commit -m "rotate VPN config to us-mia-wg-002"
git push
nru Radxa-X4   # rebuild Radxa-X4 to pick up the new VPN config
```

For a non-interactive update (replacing a secret with a file directly):

```bash
EDITOR="cp /tmp/new-config.conf" nix run nixpkgs#ragenix -- -e wireguard-vpnunlimited.age
```

---

## 🛡️ Where Secrets Land on Disk

[↑ Back to Contents](#-contents)

Agenix decrypts secrets during system activation and places them under `/run/agenix/`. The paths are only readable by root and the specified owner/group:

```nix
age.secrets.smb-credentials = {
  file  = ../../secrets/smb-credentials.age;
  owner = "root";
  mode  = "0400";
};
```

The decrypted path is available in Nix expressions as `config.age.secrets.smb-credentials.path`, which resolves to something like `/run/agenix/smb-credentials`. Secrets live in `/run/` — they are not written to disk permanently, just held in memory until the next reboot.

---

## 🆘 Troubleshooting

[↑ Back to Contents](#-contents)

| Problem | Fix |
|---------|-----|
| `agenix: secret cannot be decrypted` | The host's SSH key isn't listed as a recipient in `secrets.nix` — add it and re-key |
| `ragenix: no private key found` | `~/.ssh/id_ed25519` is missing or not readable — check it exists and permissions are `600` |
| Re-key fails with "identity not found" | Your personal key isn't listed in `linuxury-admins` in `secrets.nix` |
| Secret file is empty after activation | Decryption failed silently — run `journalctl -b \| grep agenix` to see the error |
| `age-rekey` runs but nothing changes | Check that you're in the `secrets/` directory, not the repo root |
