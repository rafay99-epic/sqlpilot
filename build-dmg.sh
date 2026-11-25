#!/bin/bash
# Builds dist/SQLServerSetup.dmg holding "SQL Server Setup.app", signed with
# the Syntax Labs Developer ID and notarized through the Apple account signed
# in to Xcode (no passwords needed). The app runs setup.sh in Terminal.
#
#   ./build-dmg.sh               # sign + notarize
#   NOTARIZE=0 ./build-dmg.sh    # sign only, for quick local tests
#   ICON=stack ./build-dmg.sh    # install (default) | stack | ember
set -euo pipefail
cd "$(dirname "$0")"

TEAM=MGH5K382YN
APP_NAME="SQL Server Setup"
BUILD=build
ARCHIVE="$BUILD/App.xcarchive"
DMG=dist/SQLServerSetup.dmg

rm -rf "$BUILD" "$DMG"
mkdir -p "$BUILD/stage" dist

# Icon: drawn by assets/icon.swift, scaled into an .icns.
swift assets/icon.swift "${ICON:-install}" "$BUILD/icon.png" 2>/dev/null
iconset="$BUILD/AppIcon.iconset"
mkdir -p "$iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$BUILD/icon.png" --out "$iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$BUILD/icon.png" --out "$iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$BUILD/AppIcon.icns"

# Generated next to the spec so its relative paths resolve; removed at the end.
xcodegen generate --quiet --spec app/project.yml --project app
echo "Archiving..."
xcodebuild -quiet -project app/SQLServerSetup.xcodeproj -destination "generic/platform=macOS" -scheme SQLServerSetup \
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
rm -rf "$BUILD" app/SQLServerSetup.xcodeproj
echo "Built $DMG"
