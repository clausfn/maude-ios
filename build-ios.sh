#!/bin/bash
# Build Liviqa for iOS Simulator (same as CI / command-line check).
set -euo pipefail
cd "$(dirname "$0")"
DEST="${1:-platform=iOS Simulator,name=iPhone 17}"
echo "Building Liviqa → $DEST"
xcodebuild -scheme Liviqa -destination "$DEST" clean build | xcbeautify 2>/dev/null || xcodebuild -scheme Liviqa -destination "$DEST" clean build
echo "BUILD SUCCEEDED"
