#!/bin/bash
# CI only: imports the Developer ID certificate into a throwaway keychain and
# writes the App Store Connect API key, so make-dmg.sh signs and notarizes.
#
# Repo secrets:
#   MACOS_DEVELOPER_ID_P12       base64 of the "Developer ID Application" .p12
#   MACOS_DEVELOPER_ID_PASSWORD  its export password
#   APPLE_API_KEY                contents of the AuthKey_XXXX.p8 file
#   APPLE_API_KEY_ID, APPLE_API_ISSUER  from App Store Connect > Users and Access > Integrations
# Missing certificate: warns and exits 0, so the build falls back to ad-hoc.
set -euo pipefail

if [ -z "${MACOS_DEVELOPER_ID_P12:-}" ]; then
  echo "::warning::MACOS_DEVELOPER_ID_P12 not set, building an ad-hoc signed (not notarized) app."
  exit 0
fi

keychain="$RUNNER_TEMP/signing.keychain-db"
password=$(openssl rand -hex 16)
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
printf '%s' "$MACOS_DEVELOPER_ID_P12" | base64 --decode >"$RUNNER_TEMP/cert.p12"
security import "$RUNNER_TEMP/cert.p12" -k "$keychain" -P "${MACOS_DEVELOPER_ID_PASSWORD:-}" -T /usr/bin/codesign
rm -f "$RUNNER_TEMP/cert.p12"
security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain" >/dev/null
# Put it first in the search list so codesign finds the identity.
existing=$(security list-keychains -d user | tr -d '"' | xargs)
# shellcheck disable=SC2086 # existing is a list of keychain paths
security list-keychains -d user -s "$keychain" $existing
echo "Imported: $(security find-identity -v -p codesigning "$keychain" | grep -o '"Developer ID Application[^"]*"')"

if [ -n "${APPLE_API_KEY:-}" ]; then
  key="$RUNNER_TEMP/AuthKey.p8"
  printf '%s\n' "$APPLE_API_KEY" >"$key"
  echo "APPLE_API_KEY_PATH=$key" >>"$GITHUB_ENV"
else
  echo "::warning::APPLE_API_KEY not set, the app will be signed but not notarized."
fi
