# ===========================================================================
# modules/users/uid-pin/test.nix — VM test for modules/users/uid-pin
#
# Recreates the server situation (UIDs handed out alphabetically: alex 1000,
# babylinux 1001, linuxury 1002 — plus container files written as raw 1000),
# reboots, and checks the boot-time migration got everything right.
#
# Run: nix build -L .#checks.x86_64-linux.uid-migrate
# ===========================================================================
{
  name = "uid-migrate";

  nodes.machine = { ... }: {
    imports = [ ./default.nix ];
    users.users = {
      alex.isNormalUser = true;
      babylinux.isNormalUser = true;
      linuxury.isNormalUser = true;
    };
    users.uidMigrate.ownedBy."/data/config/zennotes" = "linuxury";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # --- Recreate the alphabetical UIDs (linuxury 1000 → 1002, alex 1002 → 1000)
    machine.succeed("usermod -u 3000 linuxury && usermod -u 1000 alex && usermod -u 1002 linuxury")
    machine.succeed("[ $(id -u alex) = 1000 ] && [ $(id -u babylinux) = 1001 ] && [ $(id -u linuxury) = 1002 ]")

    # Files as they exist on the servers today
    machine.succeed(
      "mkdir -p /data/config/zennotes /data/media"
      " && touch /home/alex/a /home/linuxury/l /data/media/alex-movie /data/media/linuxury-movie"
      " && chown 1000 /home/alex/a /data/media/alex-movie"         # alex's own
      " && chown 1002 /home/linuxury/l /data/media/linuxury-movie" # linuxury's own
      " && touch /home/linuxury/jarvis-note /data/config/zennotes/db"
      " && chown 1000 /home/linuxury/jarvis-note /data/config/zennotes/db"  # container wrote as raw 1000
    )

    # --- Reboot: migration runs before any login
    machine.shutdown()
    machine.start()
    machine.wait_for_unit("multi-user.target")
    print(machine.succeed("cat /var/log/uid-migrate.log"))

    owner = lambda p: machine.succeed(f"stat -c %U {p}").strip()
    machine.succeed("[ $(id -u linuxury) = 1000 ] && [ $(id -u babylinux) = 1001 ] && [ $(id -u alex) = 1002 ]")
    assert owner("/home/alex/a") == "alex"
    assert owner("/data/media/alex-movie") == "alex"
    assert owner("/home/linuxury/l") == "linuxury"
    assert owner("/data/media/linuxury-movie") == "linuxury"
    assert owner("/home/linuxury/jarvis-note") == "linuxury", "home rule"
    assert owner("/data/config/zennotes/db") == "linuxury", "ownedBy rule"
    assert owner("/home/alex") == "alex" and owner("/home/linuxury") == "linuxury"

    # --- Second boot is a no-op
    machine.shutdown()
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("[ $(grep -c ' start: ' /var/log/uid-migrate.log) = 1 ]")

    # --- Logged-in user: postpones instead of failing (simulated mismatch)
    machine.succeed("usermod -u 3000 babylinux")
    machine.succeed("systemd-run --uid=babylinux --unit=hold sleep 600")
    machine.succeed("systemctl restart uid-migrate")
    machine.succeed("grep -q 'babylinux (uid 3000) is logged in — postponed' /var/log/uid-migrate.log")
    machine.succeed("[ $(id -u babylinux) = 3000 ]")
  '';
}
