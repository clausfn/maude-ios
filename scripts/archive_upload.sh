#!/usr/bin/env bash
# Archive + upload Liviqa to TestFlight — runnable headlessly (no Xcode GUI).
#
# PREREQS (one-time, yours):
#   1) Data for Good Apple ID added in Xcode ▸ Settings ▸ Accounts (gives the CLI
#      a session to mint the Apple Distribution cert + App Store profile via
#      -allowProvisioningUpdates). Team: Fonden Data For Good (PS258XSNL8).
#   2) An App Store Connect API key for upload (App Store Connect ▸ Users and
#      Access ▸ Integrations ▸ App Store Connect API ▸ generate). Put the .p8 at
#      ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8 and export:
#        export ASC_KEY_ID=XXXXXXXXXX
#        export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   3) The app record (bundle app.liviqa.ios) created in App Store Connect.
#
# Then: ./scripts/archive_upload.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE="build/Liviqa.xcarchive"
EXPORT="build/export"
rm -rf "$ARCHIVE" "$EXPORT"

echo "▸ Archiving (Release, automatic signing, provisioning updates allowed)…"
xcodebuild -scheme Liviqa -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive

echo "▸ Exporting signed .ipa…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist Config/ExportOptions.plist \
  -allowProvisioningUpdates

IPA="$(ls "$EXPORT"/*.ipa 2>/dev/null | head -1)"
[ -n "$IPA" ] || { echo "no .ipa produced"; exit 1; }
echo "▸ Built: $IPA"

if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
  echo "▸ Uploading to TestFlight via App Store Connect API key…"
  xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "✅ Uploaded. It'll appear in TestFlight after processing (~5–15 min)."
else
  echo "ℹ︎ ASC_KEY_ID / ASC_ISSUER_ID not set — skipped upload."
  echo "  Upload manually: Xcode Organizer ▸ Distribute, or set the API key vars and re-run."
fi
