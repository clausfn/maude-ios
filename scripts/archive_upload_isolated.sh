#!/bin/bash
# Headless TestFlight build via an ISOLATED keychain — sidesteps a locked/out-of-
# sync login keychain (which makes codesign hang waiting on a GUI prompt).
#
# It uses a dedicated throwaway keychain (~/liviqa-build.keychain-db) with a known
# password, makes it the sole signing keychain for the duration of the build, then
# RESTORES the user's keychain search list + default exactly as they were — the
# login keychain is never touched, and no saved passwords are lost.
#
# First run mints fresh signing certs via the App Store Connect API key; later runs
# REUSE the same keychain (no new certs). Run: ./scripts/archive_upload_isolated.sh
set -uo pipefail
cd "$(dirname "$0")/.."

BUILD_KC="$HOME/liviqa-build.keychain-db"
BUILD_PW="LiviqaBuild-2026"
export ASC_KEY_ID="${ASC_KEY_ID:-656L9P8JY3}"
export ASC_ISSUER_ID="${ASC_ISSUER_ID:-830c96d2-1922-4e68-9736-56940ebf9bc2}"
export ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_656L9P8JY3.p8}"

ORIG_DEFAULT="$(security default-keychain | sed 's/[" ]//g')"
ORIG_LIST="$(security list-keychains -d user | sed 's/[" ]//g' | tr '\n' ' ')"
restore() {
  security default-keychain -s "$ORIG_DEFAULT" 2>/dev/null
  # shellcheck disable=SC2086
  security list-keychains -d user -s $ORIG_LIST 2>/dev/null
  echo "=== restored keychain search list ==="
}
trap restore EXIT INT TERM

# Reuse the build keychain if it already exists (keeps the same signing certs).
if [ ! -f "$BUILD_KC" ]; then
  echo "=== creating build keychain (first run — will mint certs) ==="
  security create-keychain -p "$BUILD_PW" "$BUILD_KC"
fi
security set-keychain-settings "$BUILD_KC"          # no idle auto-lock
security unlock-keychain -p "$BUILD_PW" "$BUILD_KC"
security default-keychain -s "$BUILD_KC"
security list-keychains -d user -s "$BUILD_KC"      # isolate to the build keychain
# Let codesign use the keys without an interactive prompt.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$BUILD_PW" "$BUILD_KC" >/dev/null 2>&1 || true

echo "=== isolated build keychain active; archiving + uploading ==="
./scripts/archive_upload.sh
RC=$?
echo "ARCHIVE_RC=$RC"
exit $RC
