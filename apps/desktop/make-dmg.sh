#!/bin/bash
# Builds dist/SQLPilot.dmg holding SQLPilot.app, version 0.<commit count>.
#
# Signing: the Developer ID in the keychain (Syntax Labs) when present, else
# ad-hoc. Notarizing (NOTARIZE=...):
#   xcode       the Apple account signed in to Xcode (default on a Mac, no passwords)
#   notarytool  App Store Connect API key: APPLE_API_KEY_PATH, APPLE_API_KEY_ID,
#               APPLE_API_ISSUER (default when APPLE_API_KEY_PATH is set; CI)
#   none        skip (default in CI without the key, and for ad-hoc builds)
#
#   apps/desktop/make-dmg.sh
#   NOTARIZE=none apps/desktop/make-dmg.sh
#   SQLPILOT_VERSION=0.99 ICON=stack apps/desktop/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")"

ROOT=../..
TEAM=MGH5K382YN
APP_NAME="SQLPilot"
BUILD=build
ARCHIVE="$BUILD/App.xcarchive"
DMG="$ROOT/dist/SQLPilot.dmg"
VERSION="${SQLPILOT_VERSION:-0.$(git rev-list --count HEAD)}"

if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  SIGNED=1
  sign=()
else
  SIGNED=0
  sign=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= OTHER_CODE_SIGN_FLAGS= ENABLE_HARDENED_RUNTIME=NO)
fi
if [ -n "${NOTARIZE:-}" ]; then :
elif [ -n "${APPLE_API_KEY_PATH:-}" ]; then NOTARIZE=notarytool
elif [ -n "${CI:-}" ]; then NOTARIZE=none
else NOTARIZE=xcode
fi
[ "$SIGNED" = 1 ] || NOTARIZE=none
echo "SQLPilot $VERSION (signing: $([ "$SIGNED" = 1 ] && echo "Developer ID" || echo ad-hoc), notarize: $NOTARIZE)"

rm -rf "$BUILD" "$DMG"
mkdir -p "$BUILD/stage" "$ROOT/dist"

"$ROOT/assets/make-icon.sh" "${ICON:-install}" "$BUILD/AppIcon.icns"
xcodegen generate --quiet --spec project.yml
echo "Archiving..."
xcodebuild -quiet -project SQLPilot.xcodeproj -scheme SQLPilot -destination "generic/platform=macOS" \
  -configuration Release -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$VERSION" ${sign[@]+"${sign[@]}"} archive
APP="$ARCHIVE/Products/Applications/$APP_NAME.app"

case "$NOTARIZE" in
  xcode)
    cat >"$BUILD/export.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict>
</plist>
EOF
    echo "Uploading to Apple for notarization (uses the Xcode account)..."
    xcodebuild -quiet -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$BUILD/export.plist" \
      -exportPath "$BUILD/upload" -allowProvisioningUpdates
    # Apple usually answers in 1-5 minutes; exportNotarizedApp fails until then.
    echo "Waiting for Apple's notarization result..."
    for ((i = 0; i < 60; i++)); do
      if xcodebuild -quiet -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$BUILD/notarized" >"$BUILD/notary.log" 2>&1; then
        break
      fi
      if grep -qi 'invalid\|rejected' "$BUILD/notary.log"; then cat "$BUILD/notary.log"; exit 1; fi
      sleep 20
    done
    [ -d "$BUILD/notarized/$APP_NAME.app" ] || { cat "$BUILD/notary.log"; echo "Notarization did not finish in 20 minutes."; exit 1; }
    APP="$BUILD/notarized/$APP_NAME.app"
    ;;
  notarytool)
    echo "Notarizing with the App Store Connect API key..."
    ditto -c -k --keepParent "$APP" "$BUILD/notarize.zip"
    xcrun notarytool submit "$BUILD/notarize.zip" --key "$APPLE_API_KEY_PATH" \
      --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" --wait
    xcrun stapler staple "$APP"
    ;;
esac
[ "$NOTARIZE" = none ] || xcrun stapler validate "$APP"
cp -R "$APP" "$BUILD/stage/"
codesign --verify --strict --deep "$BUILD/stage/$APP_NAME.app"
# The usual drag-to-install shortcut. The app also offers to move itself there.
ln -s /Applications "$BUILD/stage/Applications"

# Writable image first so the mounted volume can carry the icon too. The DMG
# itself stays unsigned: Gatekeeper then checks the notarized app inside,
# while a signed-but-unnotarized DMG would be rejected.
rw="$BUILD/rw.dmg"
hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$BUILD/stage" -format UDRW -ov "$rw"
mnt=$(hdiutil attach -nobrowse -noautoopen "$rw" 2>/dev/null | awk -F'\t' '/\/Volumes\//{print $NF}')
cp "$BUILD/AppIcon.icns" "$mnt/.VolumeIcon.icns"
SetFile -a C "$mnt"
hdiutil detach -quiet "$mnt"
hdiutil convert -quiet "$rw" -format UDZO -o "$DMG"

spctl -a -t exec -vv "$BUILD/stage/$APP_NAME.app" 2>&1 || true
rm -rf "$BUILD" SQLPilot.xcodeproj
echo "Built $DMG ($VERSION)"
