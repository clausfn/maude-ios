#!/bin/bash
# Build Liviqa for iOS Simulator (same as CI / command-line check).
set -euo pipefail
cd "$(dirname "$0")"
DEST="${1:-platform=iOS Simulator,name=iPhone 17}"

# T-PROV-01 — provenance-never-renders guard. BLOCKING: set -e aborts the build
# on exit 1. Wired here 2026-07-03 (PR-102, launch audit — was previously inert).
bash scripts/guard_provenance.sh Liviqa

# Dead-CTA guard (PR-102 wave 3, launch audit): no live empty `Button { }`
# closures may ship in Liviqa/ views. Disabled honest stubs (SOON chip +
# .disabled(true), JournalView "Scan the label" pattern) are exempt via an
# explicit `// HONEST-STUB` marker on the Button line.
if grep -rn -E 'Button *\{ *\}' Liviqa --include='*.swift' | grep -v 'HONEST-STUB'; then
  echo "FAIL: empty Button { } closure(s) found (listed above)." >&2
  echo "Wire the action, or mark a disabled honest stub with // HONEST-STUB." >&2
  exit 1
fi

echo "Building Liviqa → $DEST"
xcodebuild -scheme Liviqa -destination "$DEST" clean build | xcbeautify 2>/dev/null || xcodebuild -scheme Liviqa -destination "$DEST" clean build
echo "BUILD SUCCEEDED"
