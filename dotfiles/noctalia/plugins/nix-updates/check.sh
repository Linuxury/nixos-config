#!/bin/sh
# Usage: check.sh FLAKE_DIR [HOST] OUT   (empty HOST = this machine's hostname)
#
# Lists packages whose version would change if the flake's inputs were updated,
# without building anything or touching the flake's own flake.lock. Writes OUT
# atomically:
#   ok <epoch>            then one "name old new" line per update
#   error <epoch>         then the tail of nix's stderr
#
# ponytail: compares name+version of systemPackages and Home Manager
# home.packages only. Patch-only fixes and module-pulled packages (kernel, libs)
# don't show; catching those needs a full closure diff, i.e. a build.

dir=$1 host=${2:-$(hostname)} out=$3
[ -n "$dir" ] && [ -n "$out" ] || { echo "usage: check.sh FLAKE_DIR [HOST] OUT" >&2; exit 2; }
# nix refuses a symlinked flake dir (common: /etc/nixos -> ~/nixos-config).
dir=$(realpath "$dir")

# One check at a time — the service and the post-update recheck can overlap.
exec 9>"$out.lock"
flock -n 9 || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

apply='cfg: builtins.concatStringsSep "\n" (map
  (p: let d = builtins.parseDrvName (p.name or ""); in "${d.name} ${d.version}")
  (cfg.environment.systemPackages
    ++ builtins.concatLists (map (u: u.home.packages) (builtins.attrValues (cfg.home-manager.users or {})))))'

pkgs() {
  nix eval --raw --no-write-lock-file --reference-lock-file "$1" \
    "$dir#nixosConfigurations.\"$host\".config" --apply "$apply" 2>>"$tmp/err" |
    awk 'NF == 2' | sort -u -k1,1
}

if nix flake update --flake "$dir" --output-lock-file "$tmp/new.lock" 2>>"$tmp/err" &&
  pkgs "$dir/flake.lock" > "$tmp/old" && [ -s "$tmp/old" ] &&
  pkgs "$tmp/new.lock" > "$tmp/new" && [ -s "$tmp/new" ]; then
  { echo "ok $(date +%s)"; join "$tmp/old" "$tmp/new" | awk '$2 != $3'; } > "$tmp/result"
else
  { echo "error $(date +%s)"; tail -n 5 "$tmp/err"; } > "$tmp/result"
fi
mv -f "$tmp/result" "$out"
