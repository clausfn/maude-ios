#!/usr/bin/env bash
# guard_release_posture.sh — BLOCKING pre-upload gate (build-integrity).
#
# Refuses to let an .ipa reach TestFlight unless it has genuine App Store /
# distribution posture. This is the guardrail that would have caught the
# 10.71–10.75 Debug/mock leak. Wire it into scripts/archive_upload.sh
# immediately BEFORE the `xcrun altool --upload-app` line:
#
#     bash scripts/guard_release_posture.sh "$IPA"
#
# Exit non-zero => set -e in archive_upload.sh aborts BEFORE upload.
set -euo pipefail

IPA="${1:?usage: guard_release_posture.sh <path-to-ipa>}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" -d "$WORK"
APP="$(ls -d "$WORK"/Payload/*.app | head -1)"
[ -n "$APP" ] || { echo "✗ no .app in ipa"; exit 1; }

ENT="$(codesign -d --entitlements :- "$APP" 2>/dev/null)"
SIG="$(codesign -dvvv "$APP" 2>&1)"
status=0

# 1) Debuggable flag must be OFF (distribution). Debug builds ship get-task-allow=true.
if /usr/libexec/PlistBuddy -c 'Print :get-task-allow' /dev/stdin <<<"$ENT" 2>/dev/null | grep -qi true; then
  echo "✗ get-task-allow=true — this is a DEVELOPMENT/DEBUG-signed build, not App Store."; status=1
else
  echo "✓ get-task-allow=false"
fi

# 2) Must be signed by an Apple Distribution cert, not Apple Development.
if echo "$SIG" | grep -q 'Authority=Apple Distribution'; then
  echo "✓ Apple Distribution certificate"
else
  echo "✗ not signed by Apple Distribution (found: $(echo "$SIG" | grep -m1 'Authority=' || echo none))"; status=1
fi

# 3) TestFlight/App Store profile marker.
if echo "$ENT" | grep -q 'beta-reports-active'; then
  echo "✓ beta-reports-active present (App Store/TestFlight profile)"
else
  echo "✗ beta-reports-active missing — wrong provisioning profile."; status=1
fi

[ "$status" -eq 0 ] && echo "✓ release-posture guard passed" || echo "✗ release-posture guard FAILED"
exit $status
