#!/usr/bin/env bash
# Xcode build wrapper for SSAMAU-iOS-App.
#
# - Handles the required `cd SSAMAU` (the .xcodeproj is nested inside
#   the SSAMAU/ subdirectory, so running `xcodebuild` from the repo
#   root errors with "directory does not contain Xcode project").
# - Defaults to iPad mini, the narrowest iPad and the canonical test
#   target — formSheet / density bugs surface there first.
#
# Usage:
#   ./scripts/build.sh                 # iPad mini (default)
#   ./scripts/build.sh iphone          # iPhone 17
#   ./scripts/build.sh ipad-mini       # explicit iPad mini
#   ./scripts/build.sh ipad-pro        # iPad Pro 13-inch (M5)
#
# When a future Xcode update renames a simulator (e.g. iPhone 17 -> 18),
# edit the DEST_* values below.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_DIR="$REPO_ROOT/SSAMAU"

if [[ ! -d "$PROJECT_DIR/SSAMAU.xcodeproj" ]]; then
  echo "error: Xcode project not found at $PROJECT_DIR/SSAMAU.xcodeproj" >&2
  exit 1
fi

TARGET="${1:-ipad-mini}"

case "$TARGET" in
  iphone)
    DEST='platform=iOS Simulator,name=iPhone 17'
    ;;
  ipad-mini|"")
    DEST='platform=iOS Simulator,name=iPad mini (A17 Pro)'
    ;;
  ipad-pro)
    DEST='platform=iOS Simulator,name=iPad Pro 13-inch (M5)'
    ;;
  -h|--help|help)
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "error: unknown target '$TARGET'" >&2
    echo "usage: $0 [iphone|ipad-mini|ipad-pro]" >&2
    exit 1
    ;;
esac

echo "==> Building SSAMAU for: $DEST"
cd "$PROJECT_DIR"
exec xcodebuild \
  -scheme SSAMAU \
  -destination "$DEST" \
  -configuration Debug \
  build
