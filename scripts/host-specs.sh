#!/usr/bin/env bash
# ===========================================================================
# scripts/host-specs.sh — record this host's build-relevant specs
#
# Writes hosts/<this host>/specs.nix, consumed by
# modules/system/build-capacity.nix to derive nix max-jobs/cores.
#
# Run once per machine, then commit the result. Re-run only if the hardware
# changes (RAM added, CPU swapped). Nix evaluation is pure and cannot read
# /proc, which is why this is a committed data file rather than detection at
# build time — and why a wrong number shows up as a reviewable diff.
#
# Hosts with no specs.nix fall to the conservative floor tier on purpose.
# ===========================================================================
set -euo pipefail

cfg="${NIXOS_CONFIG:-$HOME/nixos-config}"
host="$(hostname)"
dir="$cfg/hosts/$host"

[[ -d "$dir" ]] || { echo "no host dir: $dir" >&2; exit 1; }

cores=$(nproc)
# Truncating division floors the value, which errs conservative.
ram=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)

cat > "$dir/specs.nix" <<EOF
# Measured by scripts/host-specs.sh on $(date +%F) — re-run if hardware changes.
# Consumed by modules/system/build-capacity.nix.
{
  cores = $cores;
  ramGB = $ram;
}
EOF

echo "wrote $dir/specs.nix  ($cores cores, $ram GB)"
