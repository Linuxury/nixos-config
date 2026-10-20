# ===========================================================================
# modules/users/uid-pin/default.nix — pin family UIDs + one-time migration
#
# Imported for every host by mkHost (flake.nix).
#
# 1. PIN: every family user a host declares gets its UID from ../uids.nix.
#    Done by extending the users.users submodule, so hosts that don't declare
#    a user don't get one created.
#
# 2. MIGRATE: NixOS never changes the UID of an existing user (it only warns
#    "not applying UID change"). uid-migrate.service runs early at boot,
#    before any login or service, and for every user whose UID is wrong:
#      - records which files each old UID owns (local disks only; skips
#        /nix/store, read-only snapper snapshots, container image storage)
#      - usermod -u in two phases (old → temp → final) so swaps never collide
#      - chowns the recorded files to the new UID
#      - inside /home/<user>, hands files owned by another family user back
#        to <user> (e.g. container writes made under the wrong UID)
#      - chowns users.uidMigrate.ownedBy paths to their owner
#    When every UID already matches it exits immediately (normal state).
#    If a user that needs moving is logged in (e.g. started by a switch, not
#    a boot), it postpones to the next boot.
#
# Log: journalctl -u uid-migrate · /var/log/uid-migrate.log
# ===========================================================================
{ config, lib, pkgs, ... }:

let
  uids = import ../uids.nix;
  managed = lib.filterAttrs (n: u: uids ? ${n} && u.isNormalUser) config.users.users;
  wantDecl = lib.concatStringsSep " " (lib.mapAttrsToList (n: _: "[${n}]=${toString uids.${n}}") managed);
  ownedDecl = lib.concatStringsSep " " (lib.mapAttrsToList (p: u: "[${lib.escapeShellArg p}]=${u}") config.users.uidMigrate.ownedBy);
in
{
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      config.uid = lib.mkIf (uids ? ${name}) uids.${name};
    }));
  };

  options.users.uidMigrate.ownedBy = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    example = { "/data/config/zennotes" = "linuxury"; };
    description = ''
      Paths written by services that run with a raw UID instead of a user
      name (containers). After a migration they are chowned to this user,
      because the old UID may have belonged to someone else on this host.
    '';
  };

  config.systemd.services.uid-migrate = {
    description = "Move family users to their fixed UIDs (one-time)";
    wantedBy = [ "sysinit.target" ];
    after = [ "local-fs.target" ];
    before = [ "sysinit.target" "systemd-user-sessions.service" "systemd-logind.service" ];
    unitConfig.DefaultDependencies = false;
    restartIfChanged = false;
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; TimeoutStartSec = "infinity"; };
    path = with pkgs; [ shadow procps findutils util-linux gawk coreutils getent ];
    script = ''
      log() { echo "uid-migrate: $*"; echo "$(date -Is) $*" >> /var/log/uid-migrate.log; }
      declare -A want=( ${wantDecl} ) owned=( ${ownedDecl} ) old=()

      for u in "''${!want[@]}"; do
        cur=$(id -u "$u" 2>/dev/null) || continue   # not created yet: gets the pinned UID directly
        [[ $cur == "''${want[$u]}" ]] || old[$u]=$cur
      done
      (( ''${#old[@]} )) || exit 0

      for u in "''${!old[@]}"; do
        if pgrep -u "''${old[$u]}" >/dev/null; then
          log "$u (uid ''${old[$u]}) is logged in — postponed to next boot"; exit 0
        fi
      done
      log "start: $(for u in "''${!old[@]}"; do printf '%s %s→%s  ' "$u" "''${old[$u]}" "''${want[$u]}"; done)"

      # 1. Record files per old UID, before usermod touches anything.
      work=/run/uid-migrate; rm -rf "$work"; mkdir -p "$work"
      match=(); for u in "''${!old[@]}"; do match+=(-o -uid "''${old[$u]}"); done
      while read -r m; do
        find "$m" -xdev \( -path '/nix/store*' -o -path '*/.snapshots*' -o -path '/var/lib/containers*' -o -path '/var/lib/docker*' \) -prune \
             -o \( -false "''${match[@]}" \) -printf '%U/%p\0' \
          | gawk -v RS='\0' -v ORS='\0' -v dir="$work" '{ i = index($0, "/"); print substr($0, i + 1) > (dir "/" substr($0, 1, i - 1)) }'
      done < <(findmnt -rn -o TARGET -t btrfs,ext4,xfs,f2fs,bcachefs,zfs | sort -u)

      # 2. usermod: old → temp → final, so swapped UIDs never collide.
      for u in "''${!old[@]}"; do usermod -u $(( 50000 + want[$u] )) "$u"; done
      for u in "''${!old[@]}"; do usermod -u "''${want[$u]}" "$u"; done

      # 3. Hand the recorded files to the new UIDs.
      for u in "''${!old[@]}"; do
        f="$work/''${old[$u]}"; [[ -s $f ]] || continue
        xargs -0 -r chown -h "''${want[$u]}" < "$f" 2>>/var/log/uid-migrate.log || true
        log "$u: $(tr -cd '\0' < "$f" | wc -c) files → uid ''${want[$u]}"
      done

      # 4. A home belongs to its user: fix files another family user owns there.
      for u in "''${!want[@]}"; do
        home=$(getent passwd "$u" | cut -d: -f6); [[ -d $home ]] || continue
        others=(); for o in "''${!want[@]}"; do [[ $o == "$u" ]] || others+=(-o -uid "''${want[$o]}"); done
        find "$home" -xdev -path '*/.snapshots' -prune -o \( -false "''${others[@]}" \) -exec chown -h "$u" {} + || true
      done

      # 5. Paths written by raw-UID services (containers).
      for p in "''${!owned[@]}"; do [[ -e $p ]] && chown -Rh "''${owned[$p]}" "$p" && log "$p → ''${owned[$p]}"; done

      rm -rf "$work"
      log "done"
    '';
  };
}
