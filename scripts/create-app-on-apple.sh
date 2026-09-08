#!/usr/bin/env bash
#
# Create Maude on Apple's side. RUN THIS ON YOUR OWN MAC — it cannot work anywhere else.
#
#   bash scripts/create-app-on-apple.sh
#
# WHY THIS SCRIPT EXISTS
#
# Adding an app to Apple's list of apps is the one part of getting onto TestFlight
# that no API key can do. Apple's official App Store Connect API has no endpoint
# that creates an app record — an App Manager key gets a 403 for it. The only
# automated route is the one fastlane uses: it signs in as you, with your Apple ID,
# your password and a code from your phone, over the same web session a browser
# would use. That is why this has to run on your machine and not in a data centre.
#
# It is also almost certainly how Liviqa was set up: a session on this Mac drove
# fastlane, and the only human moment was approving one 2FA code.
#
# WHAT IT DOES, AND WHAT IT DELIBERATELY DOES NOT
#
# Does:      creates the App ID `xyz.ppcn.maude` on the developer portal, and the
#            matching app record in App Store Connect, named Maude.
# Does not:  touch capabilities, certificates or profiles. The release pipeline
#            already creates those with `-allowProvisioningUpdates`, and doing it
#            twice by two different routes is how they drift apart.
#
# Nothing is stored. Your password goes to Apple through fastlane and is never
# written to disk by this script, never printed, and never leaves your machine.

set -euo pipefail

APP_NAME="Maude"
BUNDLE_ID="xyz.ppcn.maude"
SKU="maude-ppcn"
LANGUAGE="English_UK"

say() { printf '\n%s\n' "$*"; }

# ---------------------------------------------------------------- preflight --
if ! command -v fastlane >/dev/null 2>&1; then
  say "fastlane is not installed. It is the tool that can talk to Apple as you."
  echo "Install it with one of these, then run this script again:"
  echo
  echo "    brew install fastlane"
  echo "    # or, if you do not use Homebrew:"
  echo "    sudo gem install fastlane"
  exit 1
fi

say "This will create, on Apple's side:"
echo "    App name     $APP_NAME"
echo "    App ID       $BUNDLE_ID"
echo "    Reference    $SKU        (internal only — nobody ever sees it)"
echo "    Language     $LANGUAGE"
echo
echo "It does NOT submit anything for review. Nobody at Apple looks at this."

# --------------------------------------------------------------- your login --
if [ -z "${APPLE_ID:-}" ]; then
  printf '\nApple ID (the email you sign in to Apple Developer with): '
  read -r APPLE_ID
fi
[ -n "$APPLE_ID" ] || { echo "No Apple ID given. Nothing done."; exit 1; }

# Optional. Only needed if this Apple ID belongs to more than one team, in which
# case fastlane would otherwise stop and ask you to choose.
if [ -z "${FASTLANE_ITC_TEAM_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
  export FASTLANE_TEAM_ID="$APPLE_TEAM_ID"
fi

printf '\nGo ahead? [y/N] '
read -r answer
case "$answer" in
  y|Y|yes|YES) ;;
  *) echo "Nothing done."; exit 0 ;;
esac

# ------------------------------------------------------------------- create --
say "Signing in to Apple. Expect a password prompt, then a code on your phone."
echo "If it asks to store the password in your keychain, that is fastlane's own"
echo "prompt and it is safe to accept — it stays on this machine."
echo

fastlane produce create \
  --username "$APPLE_ID" \
  --app_identifier "$BUNDLE_ID" \
  --app_name "$APP_NAME" \
  --sku "$SKU" \
  --language "$LANGUAGE" \
  --platform ios

say "Done. Maude now exists on Apple's side."
echo
echo "Next: go to GitHub, open the TestFlight workflow, and run it with"
echo "mode = upload. That builds the app and sends it."
echo
echo "    https://github.com/clausfn/maude-ios/actions/workflows/release.yml"
echo
echo "If Apple says the App ID is already taken, it is registered under a"
echo "different Apple account. Send me the exact wording rather than guessing."
