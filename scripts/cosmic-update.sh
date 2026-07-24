#!/usr/bin/env bash
# ===========================================================================
# scripts/cosmic-update.sh — COSMIC Desktop version updater
#
# Called by nru when cosmic-session is installed and a new epoch tag exists.
# Usage: cosmic-update.sh <NIXOS_CONFIG> <NEW_VERSION>
#
# Phases:
#   1. Fetch src hashes for all packages in parallel (fast, network-bound)
#   2. Resolve cargo vendor hashes in parallel via fake-hash trick (slow)
#   3. Sed-update all sentinel comments in the overlay file
#   4. Update cosmicVersion sentinel
#   5. Detect new pop-os/cosmic-epoch submodules not yet in the overlay;
#      auto-add if in nixpkgs, warn otherwise
# ===========================================================================
set -euo pipefail

NIXOS_CONFIG="$1"
NEW_VER="$2"
OVERLAY="${NIXOS_CONFIG}/pkgs/cosmic-overlay/default.nix"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# ---------------------------------------------------------------------------
# Package metadata — parallel arrays: nixpkg name, repo name, is_rust (1/0)
# Keep in sync with the overlay sentinel comments.
# ---------------------------------------------------------------------------
declare -A PKG_REPO   # nixpkg_name -> github repo name
declare -A PKG_RUST   # nixpkg_name -> 1 if Rust build, 0 if asset

PKG_REPO=(
  [cosmic-app-library]=cosmic-applibrary
  [cosmic-applets]=cosmic-applets
  [cosmic-bg]=cosmic-bg
  [cosmic-comp]=cosmic-comp
  [cosmic-edit]=cosmic-edit
  [cosmic-files]=cosmic-files
  [cosmic-greeter]=cosmic-greeter
  [cosmic-icons]=cosmic-icons
  [cosmic-idle]=cosmic-idle
  [cosmic-initial-setup]=cosmic-initial-setup
  [cosmic-launcher]=cosmic-launcher
  [cosmic-monitor]=cosmic-monitor
  [cosmic-notifications]=cosmic-notifications
  [cosmic-osd]=cosmic-osd
  [cosmic-panel]=cosmic-panel
  [cosmic-player]=cosmic-player
  [cosmic-randr]=cosmic-randr
  [cosmic-screenshot]=cosmic-screenshot
  [cosmic-session]=cosmic-session
  [cosmic-settings]=cosmic-settings
  [cosmic-settings-daemon]=cosmic-settings-daemon
  [cosmic-store]=cosmic-store
  [cosmic-term]=cosmic-term
  [cosmic-workspaces-epoch]=cosmic-workspaces-epoch
  [xdg-desktop-portal-cosmic]=xdg-desktop-portal-cosmic
  [cosmic-sound-theme]=cosmic-sound-theme
  [cosmic-wallpapers]=cosmic-wallpapers
)

PKG_RUST=(
  [cosmic-app-library]=1
  [cosmic-applets]=1
  [cosmic-bg]=1
  [cosmic-comp]=1
  [cosmic-edit]=1
  [cosmic-files]=1
  [cosmic-greeter]=1
  [cosmic-icons]=0
  [cosmic-idle]=1
  [cosmic-initial-setup]=1
  [cosmic-launcher]=1
  [cosmic-monitor]=1
  [cosmic-notifications]=1
  [cosmic-osd]=1
  [cosmic-panel]=1
  [cosmic-player]=1
  [cosmic-randr]=1
  [cosmic-screenshot]=1
  [cosmic-session]=1
  [cosmic-settings]=1
  [cosmic-settings-daemon]=1
  [cosmic-store]=1
  [cosmic-term]=1
  [cosmic-workspaces-epoch]=1
  [xdg-desktop-portal-cosmic]=1
  [cosmic-sound-theme]=0
  [cosmic-wallpapers]=0
)

# Submodule repo names that are not standalone versioned packages.
# pop-launcher has its own release cycle; cosmic-epoch tracks it as a
# build dependency but doesn't epoch-tag it.
SKIP_SUBMODULES=(pop-launcher docs scripts)

# Reverse map: repo name -> nixpkg name (for new package detection)
declare -A REPO_TO_PKG
for pkg in "${!PKG_REPO[@]}"; do
  REPO_TO_PKG[${PKG_REPO[$pkg]}]="$pkg"
done

# ---------------------------------------------------------------------------
# Phase 1 — fetch src hashes in parallel (max 8 concurrent)
# ---------------------------------------------------------------------------
echo ":: Fetching src hashes for epoch-${NEW_VER}..." >&2

MAX_JOBS=8
active_jobs=0

for pkg in "${!PKG_REPO[@]}"; do
  repo="${PKG_REPO[$pkg]}"
  url="https://github.com/pop-os/${repo}/archive/refs/tags/epoch-${NEW_VER}.tar.gz"
  (
    hash=$(nix store prefetch-file --hash-type sha256 --unpack "$url" 2>&1 \
      | grep -oP 'sha256-[A-Za-z0-9+/=]+' | tail -1)
    if [[ -z "$hash" ]]; then
      echo "FAIL: no src hash for ${pkg}" >&2
      exit 1
    fi
    echo "$hash" > "${TMP}/${pkg}.src"
  ) &

  (( active_jobs++ ))
  if (( active_jobs >= MAX_JOBS )); then
    wait -n 2>/dev/null || wait
    (( active_jobs-- ))
  fi
done
wait

# Verify all src hashes landed
for pkg in "${!PKG_REPO[@]}"; do
  if [[ ! -f "${TMP}/${pkg}.src" ]]; then
    echo "ERROR: src hash missing for ${pkg}" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Phase 2 — resolve cargo vendor hashes in parallel (max 4, CPU+RAM bound)
# Uses the fake-hash trick: write sha256-FAKE, nix fetches vendor dir,
# reports the correct hash in the error output. We capture and extract it.
# Only runs for Rust packages (PKG_RUST[$pkg] == 1).
# ---------------------------------------------------------------------------
echo ":: Resolving cargo vendor hashes (this may take a few minutes)..." >&2

MAX_JOBS=4
active_jobs=0

for pkg in "${!PKG_RUST[@]}"; do
  [[ "${PKG_RUST[$pkg]}" -eq 0 ]] && continue
  repo="${PKG_REPO[$pkg]}"
  src_hash=$(< "${TMP}/${pkg}.src")

  (
    # Evaluate fetchCargoVendor with a fake hash.
    # nix build will fail but stderr contains "got: sha256-REAL"
    nix_expr="
      let
        pkgs = import <nixpkgs> {};
        src  = pkgs.fetchFromGitHub {
          owner = \"pop-os\";
          repo  = \"${repo}\";
          tag   = \"epoch-${NEW_VER}\";
          hash  = \"${src_hash}\";
        };
      in pkgs.rustPlatform.fetchCargoVendor {
        pname   = \"${pkg}\";
        version = \"${NEW_VER}\";
        inherit src;
        hash    = \"${FAKE_HASH}\";
      }"

    cargo_hash=$(nix build --impure --no-link --expr "$nix_expr" 2>&1 \
      | grep -oP '(?<=got:)\s*sha256-[A-Za-z0-9+/=]+' | tr -d ' ' | tail -1)

    if [[ -z "$cargo_hash" ]]; then
      echo "ERROR: cargo hash not found for ${pkg}" >&2
      exit 1
    fi
    echo "$cargo_hash" > "${TMP}/${pkg}.cargo"
  ) &

  (( active_jobs++ ))
  if (( active_jobs >= MAX_JOBS )); then
    wait -n 2>/dev/null || wait
    (( active_jobs-- ))
  fi
done
wait

# ---------------------------------------------------------------------------
# Phase 3 — sed-update all sentinel comments in the overlay
# Line-selection sed: match the sentinel comment, replace the hash on that
# line. Does not depend on surrounding context — safe for any order of edits.
# ---------------------------------------------------------------------------
echo ":: Updating overlay hashes..." >&2

for pkg in "${!PKG_REPO[@]}"; do
  src_hash=$(< "${TMP}/${pkg}.src")

  # Replace src hash on the line containing # cosmic-src-<pkg>
  sed -i "/# cosmic-src-${pkg}/s|sha256-[A-Za-z0-9+/=]*|${src_hash}|" "$OVERLAY"

  # Replace cargo hash if this is a Rust package
  if [[ "${PKG_RUST[$pkg]}" -eq 1 ]]; then
    cargo_hash=$(< "${TMP}/${pkg}.cargo")
    sed -i "/# cosmic-cargo-${pkg}/s|sha256-[A-Za-z0-9+/=]*|${cargo_hash}|" "$OVERLAY"
  fi
done

# Update the version sentinel
sed -i "s/cosmicVersion = \"[0-9.]*\"; # cosmic-version-nru/cosmicVersion = \"${NEW_VER}\"; # cosmic-version-nru/" "$OVERLAY"

# ---------------------------------------------------------------------------
# Phase 4 — detect new submodules in pop-os/cosmic-epoch at the new tag
# ---------------------------------------------------------------------------
echo ":: Checking for new COSMIC components..." >&2

# Fetch .gitmodules from cosmic-epoch at the new tag
gitmodules=$(gh api \
  "repos/pop-os/cosmic-epoch/contents/.gitmodules?ref=epoch-${NEW_VER}" \
  --jq '.content' 2>/dev/null | base64 -d 2>/dev/null) || {
  echo "  ⚠ Could not fetch cosmic-epoch .gitmodules — skipping new-package detection" >&2
  exit 0
}

# Extract submodule path names (these match repo names)
mapfile -t submodule_repos < <(echo "$gitmodules" | grep '^\s*path = ' | sed 's/.*path = //' | tr -d ' ')

# Collect packages currently in our overlay (from sentinel comments)
mapfile -t overlay_pkgs < <(grep -oP '(?<=# cosmic-src-)\S+' "$OVERLAY")

NEW_PACKAGES=()
for repo in "${submodule_repos[@]}"; do
  # Skip non-versioned submodules
  skip=0
  for s in "${SKIP_SUBMODULES[@]}"; do
    [[ "$repo" == "$s" ]] && skip=1 && break
  done
  [[ $skip -eq 1 ]] && continue

  # Map repo name to nixpkg name
  pkg="${REPO_TO_PKG[$repo]:-$repo}"

  # Check if already in our overlay
  found=0
  for existing in "${overlay_pkgs[@]}"; do
    [[ "$existing" == "$pkg" ]] && found=1 && break
  done
  [[ $found -eq 1 ]] && continue

  NEW_PACKAGES+=("$pkg:$repo")
done

if [[ ${#NEW_PACKAGES[@]} -eq 0 ]]; then
  echo "  No new components detected." >&2
  exit 0
fi

echo "  New components detected: ${NEW_PACKAGES[*]}" >&2

# Try to auto-add each new package
for entry in "${NEW_PACKAGES[@]}"; do
  pkg="${entry%%:*}"
  repo="${entry##*:}"

  # Check if it exists in nixpkgs
  pkg_pname=$(nix eval --raw "nixpkgs#${pkg}.pname" 2>/dev/null) || {
    echo "  ⚠ ${pkg}: not in nixpkgs yet — add manually to pkgs/cosmic-overlay/default.nix" >&2
    continue
  }

  echo "  Auto-adding ${pkg} (nixpkgs confirmed, repo: ${repo})..." >&2

  # Fetch src hash
  url="https://github.com/pop-os/${repo}/archive/refs/tags/epoch-${NEW_VER}.tar.gz"
  src_hash=$(nix store prefetch-file --hash-type sha256 --unpack "$url" 2>&1 \
    | grep -oP 'sha256-[A-Za-z0-9+/=]+' | tail -1)
  [[ -z "$src_hash" ]] && echo "  ⚠ ${pkg}: src hash failed — skipping" >&2 && continue

  # Detect if Rust (Cargo.toml present at repo root)
  is_rust=0
  gh api "repos/pop-os/${repo}/contents/Cargo.toml?ref=epoch-${NEW_VER}" &>/dev/null && is_rust=1

  if [[ $is_rust -eq 1 ]]; then
    # Fetch cargo hash
    nix_expr="
      let
        pkgs = import <nixpkgs> {};
        src  = pkgs.fetchFromGitHub {
          owner = \"pop-os\";
          repo  = \"${repo}\";
          tag   = \"epoch-${NEW_VER}\";
          hash  = \"${src_hash}\";
        };
      in pkgs.rustPlatform.fetchCargoVendor {
        pname   = \"${pkg}\";
        version = \"${NEW_VER}\";
        inherit src;
        hash    = \"${FAKE_HASH}\";
      }"
    cargo_hash=$(nix build --impure --no-link --expr "$nix_expr" 2>&1 \
      | grep -oP '(?<=got:)\s*sha256-[A-Za-z0-9+/=]+' | tr -d ' ' | tail -1)
    [[ -z "$cargo_hash" ]] && echo "  ⚠ ${pkg}: cargo hash failed — skipping" >&2 && continue

    new_entry="
  ${pkg} = mkCosmic \"${pkg}\" \"${repo}\"
    \"${src_hash}\" # cosmic-src-${pkg}
    \"${cargo_hash}\"; # cosmic-cargo-${pkg}
"
    # Insert before the non-Rust section header
    sed -i "/# ── Non-Rust asset packages/i\\${new_entry}" "$OVERLAY"
  else
    new_entry="
  ${pkg} = mkCosmicAsset \"${pkg}\" \"${repo}\"
    \"${src_hash}\"; # cosmic-src-${pkg}
"
    # Append before the closing brace of the overlay
    sed -i "/^}$/i\\${new_entry}" "$OVERLAY"
  fi

  echo "  ✓ ${pkg} added to overlay" >&2

  # Add to metadata maps for future nru runs (they read the overlay sentinels, not this script)
done

echo ":: COSMIC update complete: ${NEW_VER}" >&2
