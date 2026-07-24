#!/usr/bin/env bash
# ===========================================================================
# scripts/noctalia-update.sh — Noctalia version updater
#
# Called by nru when noctalia is installed and a new release tag exists.
# Usage: noctalia-update.sh <NIXOS_CONFIG> <NEW_TAG>
#
# Updates the noctalia flake input ref in flake.nix, then runs
# nix flake update noctalia so flake.lock resolves the new tag commit.
# ===========================================================================
set -euo pipefail

NIXOS_CONFIG="$1"
NEW_TAG="$2"
FLAKE="${NIXOS_CONFIG}/flake.nix"

# Sed-update the flake input URL ref sentinel.
# Matches: github:noctalia-dev/noctalia/<anything>"; # noctalia-version-nru
sed -i \
  "s|github:noctalia-dev/noctalia/[^\"]*\"; # noctalia-version-nru|github:noctalia-dev/noctalia/${NEW_TAG}\"; # noctalia-version-nru|" \
  "$FLAKE"

# Re-lock the updated input so flake.lock matches the new ref.
nix flake update noctalia --flake "$NIXOS_CONFIG" 2>&1
