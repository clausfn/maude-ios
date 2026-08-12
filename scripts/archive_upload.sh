#!/usr/bin/env bash
# Archive + upload Liviqa to TestFlight — runnable headlessly (no Xcode GUI).
#
# PREREQS (one-time, yours — only TWO things):
#   1) An App Store Connect API key, role **Admin** (App Store Connect ▸ Users and
#      Access ▸ Integrations ▸ App Store Connect API ▸ "+"). Download AuthKey_<ID>.p8
#      (one-time download!) and note its Key ID + Issuer ID. With this key the CLI
#      creates the App ID, App Group, Apple Distribution cert, and profile itself
#      — no Xcode account needed. Then:
#        export ASC_KEY_ID=XXXXXXXXXX
#        export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#        export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
#      (also keep the .p8 at that ~/.appstoreconnect/private_keys path so the
#       upload step's altool finds it.)
#   2) The app record (bundle app.liviqa.ios) created in App Store Connect ▸ Apps.
#      (I can do this for you in the browser via the Chrome extension.)
#
# Then: ./scripts/archive_upload.sh   (I can run this for you once 1 & 2 are done.)
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE="build/Liviqa.xcarchive"
EXPORT="build/export"
rm -rf "$ARCHIVE" "$EXPORT"

# If an API key is provided, xcodebuild uses it to create the App ID, the Apple
# Distribution cert, and the profile — fully headless, no Xcode account needed.
# (The key needs role Admin so it can create the distribution certificate.)
AUTH=()
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
  AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

# T-PROV-01 — provenance-never-renders guard. BLOCKING, PRE-ARCHIVE: `set -e`
# aborts before anything is built. The dev chain (build-ios.sh) has run this
# since 2026-07-03; the RELEASE chain must never be the weaker of the two —
# a Release archive is exactly where an un-guarded regression would ship.
echo "▸ Verifying provenance-never-renders guard before archiving…"
bash scripts/guard_provenance.sh Liviqa

echo "▸ Archiving (Release, automatic signing, provisioning updates allowed)…"
xcodebuild -scheme Liviqa -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates "${AUTH[@]}" \
  archive

echo "▸ Exporting signed .ipa…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist Config/ExportOptions.plist \
  -allowProvisioningUpdates "${AUTH[@]}"

IPA="$(ls "$EXPORT"/*.ipa 2>/dev/null | head -1)"
[ -n "$IPA" ] || { echo "no .ipa produced"; exit 1; }
echo "▸ Built: $IPA"

if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
  # BLOCKING build-integrity gate — the 10.71–10.75 Debug/mock-leak guardrail.
  # Asserts on the EXPORTED .ipa: get-task-allow=false, Apple Distribution cert,
  # beta-reports-active present. set -e aborts the upload if the guard exits non-zero.
  echo "▸ Verifying release posture of exported .ipa before upload…"
  bash scripts/guard_release_posture.sh "$IPA"
  echo "▸ Uploading to TestFlight via App Store Connect API key…"
  xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "✅ Uploaded. It'll appear in TestFlight after processing (~5–15 min)."
else
  echo "ℹ︎ ASC_KEY_ID / ASC_ISSUER_ID not set — skipped upload."
  echo "  Upload manually: Xcode Organizer ▸ Distribute, or set the API key vars and re-run."
fi
