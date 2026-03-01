# Admin Machine Setup

This is a one-time procedure done on the machine you manage the flake from — the admin machine. You only do this once, not per host. Currently that is the **ThinkPad** and **Ryzen5900x**.

---

## 1. Generate your SSH key pair

```bash
ssh-keygen -t ed25519 -C "linuxurypr@gmail.com"
```

The keys are saved to `~/.ssh/id_ed25519` (private) and `~/.ssh/id_ed25519.pub` (public).

---

## 2. Clone the config

```bash
git clone git@github.com:linuxury/nixos-config.git ~/nixos-config
cd ~/nixos-config
```

---

## 3. Add your personal key to secrets.nix

Open `secrets/secrets.nix` and replace the `linuxury-personal` placeholder with the output of:

```bash
cat ~/.ssh/id_ed25519.pub
```

---

## 4. Create the encrypted secrets

The `age-edit` alias expands to `nix run github:ryantm/agenix -- -e`. It opens `$EDITOR` for each secret — type or paste the value, save, and close.

> Do **not** use `nix run nixpkgs#agenix` — agenix is not in nixpkgs.

```bash
# linuxury's SSH authorized key — paste output of: cat ~/.ssh/id_ed25519.pub
age-edit secrets/linuxury-authorized-key.age

# FreshRSS admin password (Radxa-X4 only)
age-edit secrets/freshrss-admin-password.age

# WireGuard config for qBittorrent VPN (babylinux machines)
# Paste the full wg-quick config exported from VPN Unlimited app
age-edit secrets/wireguard-vpnunlimited.age
```

At this point the secrets are encrypted to your personal key only. After each host's first boot you add its host key and re-key (covered in the main README under **After First Boot**).

---

## 5. Set up git remote over SSH

Make sure your remote is SSH, not HTTPS. HTTPS will break `git push` once GitHub removes password auth:

```bash
git remote set-url origin git@github.com:Linuxury/nixos-config.git
git remote -v   # should show git@github.com:...
```

Add the public key to GitHub: **Settings → SSH and GPG keys → New SSH key**, then verify:

```bash
ssh -T git@github.com
# Expected: "Hi Linuxury! You've successfully authenticated..."
```

---

## 6. Register this machine in secrets.nix

Each admin machine needs its own entry in `secrets.nix` so it can re-key secrets independently. Add the machine's public key under the `linuxury-admins` list:

```nix
# PERSONAL SSH KEYS
linuxury-personal  = "ssh-ed25519 AAAA...";   # original admin key
thinkpad-personal  = "ssh-ed25519 AAAA...";   # ThinkPad key (add after ThinkPad setup)
ryzen5900x-personal = "ssh-ed25519 AAAA...";  # Ryzen5900x key (add after setup)

# Admin group — machines that can re-key secrets
linuxury-admins = [ linuxury-personal thinkpad-personal ryzen5900x-personal ];
```

Re-key after updating:

```bash
age-rekey
git add secrets/
git commit -m "register new admin machine key"
git push
```

---

## Re-key reference

Re-key is required any time you add or change a key in `secrets/secrets.nix`. Run from any machine listed in `linuxury-admins`:

```bash
cd ~/nixos-config/secrets
nix run github:ryantm/agenix -- -r
```

The `-r` flag re-encrypts every `.age` file to the current set of recipients.

> Re-key requires `~/.ssh/id_ed25519` (your personal private key) to be present on the machine you run it from.
