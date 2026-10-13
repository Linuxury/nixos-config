#!/bin/sh
# Usage: check.sh FLAKE_DIR [HOST] OUT [COMPARE] [FLATPAK]
#   HOST     empty = this machine's hostname
#   COMPARE  upstream (default) — newest versions of every flake input
#            remote             — the flake.lock on the git remote (for machines
#                                 that only pull a lock another machine pushes);
#                                 needs no GitHub API calls
#   FLATPAK  1 = also list pending Flatpak updates (user + system)
#
# Lists updates without building anything or touching the flake's own
# flake.lock. Writes OUT atomically:
#   ok <epoch>            then one tab-separated "kind name old new" line per
#                         update, kind = nix | flatpak
#   error <epoch>         then the tail of nix's stderr
#
# ponytail: compares name+version of systemPackages and Home Manager
# home.packages only. Patch-only fixes and module-pulled packages (kernel, libs)
# don't show; catching those needs a full closure diff, i.e. a build.

dir=$1 host=${2:-$(hostname)} out=$3 compare=${4:-upstream} flatpak=${5:-0}
[ -n "$dir" ] && [ -n "$out" ] || { echo "usage: check.sh FLAKE_DIR [HOST] OUT [COMPARE] [FLATPAK]" >&2; exit 2; }
# nix refuses a symlinked flake dir (common: /etc/nixos -> ~/nixos-config).
dir=$(realpath "$dir")

# One check at a time — the service and the post-update recheck can overlap.
exec 9>"$out.lock"
flock -n 9 || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tab=$(printf '\t')

apply='cfg: builtins.concatStringsSep "\n" (map
  (p: let d = builtins.parseDrvName (p.name or ""); in "${d.name} ${d.version}")
  (cfg.environment.systemPackages
    ++ builtins.concatLists (map (u: u.home.packages) (builtins.attrValues (cfg.home-manager.users or {})))))'

pkgs() {
  nix eval --raw --no-write-lock-file --reference-lock-file "$1" \
    "$dir#nixosConfigurations.\"$host\".config" --apply "$apply" 2>>"$tmp/err" |
    awk 'NF == 2' | sort -u -k1,1
}

new_lock() {
  if [ "$compare" = remote ]; then
    git -C "$dir" fetch -q 2>>"$tmp/err" && git -C "$dir" show '@{u}:./flake.lock' > "$tmp/new.lock" 2>>"$tmp/err"
  else
    nix flake update --flake "$dir" --output-lock-file "$tmp/new.lock" 2>>"$tmp/err"
  fi
}

# Pending Flatpak updates for one scope: "flatpak<TAB>Name (scope)<TAB>old<TAB>new".
# Runtimes often carry no version; "update" stands in for the new one.
flatpaks() {
  flatpak list --"$1" --columns=application,branch,version 2>/dev/null > "$tmp/fp-installed"
  flatpak remote-ls --updates --"$1" --columns=application,branch,name,version 2>/dev/null |
    awk -F'\t' -v scope="$1" '
      NR == FNR { have[$1 FS $2] = $3; next }
      { printf "flatpak\t%s (%s)\t%s\t%s\n", $3, scope, have[$1 FS $2], ($4 == "" ? "update" : $4) }
    ' "$tmp/fp-installed" -
}

if new_lock && pkgs "$dir/flake.lock" > "$tmp/old" && [ -s "$tmp/old" ]; then
  if cmp -s "$dir/flake.lock" "$tmp/new.lock"; then
    : > "$tmp/nix"   # same lock — nothing to compare
  elif pkgs "$tmp/new.lock" > "$tmp/new" && [ -s "$tmp/new" ]; then
    join "$tmp/old" "$tmp/new" | awk -v OFS="$tab" '$2 != $3 { print "nix", $1, $2, $3 }' > "$tmp/nix"
  fi
fi

if [ -f "$tmp/nix" ]; then
  {
    echo "ok $(date +%s)"
    cat "$tmp/nix"
    if [ "$flatpak" = 1 ] && command -v flatpak >/dev/null; then
      flatpaks user
      flatpaks system
    fi
  } > "$tmp/result"
else
  { echo "error $(date +%s)"; tail -n 5 "$tmp/err"; } > "$tmp/result"
fi
mv -f "$tmp/result" "$out"
