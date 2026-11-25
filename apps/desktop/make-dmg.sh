#!/bin/bash
# Builds dist/SQLPilot.dmg holding SQLPilot.app, signed with
# the Syntax Labs Developer ID and notarized through the Apple account signed
# in to Xcode (no passwords needed).
#
#   apps/desktop/make-dmg.sh               # sign + notarize
#   NOTARIZE=0 apps/desktop/make-dmg.sh    # sign only, for quick local tests
#   ICON=stack apps/desktop/make-dmg.sh    # install (default) | stack | ember
set -euo pipefail
cd "$(dirname "$0")"

ROOT=../..
TEAM=MGH5K382YN
APP_NAME="SQLPilot"
BUILD=build
ARCHIVE="$BUILD/App.xcarchive"
DMG="$ROOT/dist/SQLPilot.dmg"

rm -rf "$BUILD" "$DMG"
mkdir -p "$BUILD/stage" "$ROOT/dist"

"$ROOT/assets/make-icon.sh" "${ICON:-install}" "$BUILD/AppIcon.icns"
xcodegen generate --quiet --spec project.yml
echo "Archiving..."
xcodebuild -quiet -project SQLPilot.xcodeproj -scheme SQLPilot -destination "generic/platform=macOS" \
  -configuration Release -archivePath "$ARCHIVE" archive

if [ "${NOTARIZE:-1}" = 1 ]; then
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
  xcrun stapler validate "$BUILD/notarized/$APP_NAME.app"
  cp -R "$BUILD/notarized/$APP_NAME.app" "$BUILD/stage/"
else
  cp -R "$ARCHIVE/Products/Applications/$APP_NAME.app" "$BUILD/stage/"
fi
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
echo "Built $DMG"
