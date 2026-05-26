#!/usr/bin/env bash
# Bumps CURRENT_PROJECT_VERSION (the iOS "build number") to the current
# git commit count + a fixed offset so it always monotonically increases
# even after rebase/squash. Run this whenever you want to cut a new
# build for TestFlight / device install.
#
# Marketing version (MARKETING_VERSION) stays at whatever's set in
# project.pbxproj — bump that manually when the user-facing version
# changes (Beta 0.1 → Beta 0.2 → 1.0).
#
# Usage:
#   ./scripts/bump-build.sh           # use commit count
#   ./scripts/bump-build.sh 123       # explicit build number override

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PBXPROJ="$REPO_ROOT/SSAMAU/SSAMAU.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
  echo "error: project.pbxproj not found at $PBXPROJ" >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  NEW_BUILD="$1"
else
  COMMITS="$(git -C "$REPO_ROOT" rev-list --count HEAD)"
  # +1 so the FIRST run isn't 0; matches the convention that the very
  # first build is build 1.
  NEW_BUILD=$((COMMITS + 1))
fi

# Show current state.
CURRENT="$(grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed -E 's/.*CURRENT_PROJECT_VERSION = ([0-9]+);.*/\1/')"
MARKETING="$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([0-9.]+);.*/\1/')"

echo "marketing: $MARKETING"
echo "build:     $CURRENT  →  $NEW_BUILD"

# Replace every CURRENT_PROJECT_VERSION = N; with the new value. Both
# Debug + Release configurations share the same build number, which is
# what TestFlight + App Store expect.
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"
else
  sed -i -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"
fi
echo "ok"
