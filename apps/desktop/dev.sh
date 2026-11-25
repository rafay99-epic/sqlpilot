#!/bin/bash
# Debug build for development, ad-hoc signed (no Developer ID needed).
#   apps/desktop/dev.sh          # build and open the app
#   apps/desktop/dev.sh test     # run the unit tests
set -euo pipefail
cd "$(dirname "$0")"

[ -f build/AppIcon.icns ] || ../../assets/make-icon.sh install build/AppIcon.icns
xcodegen generate --quiet --spec project.yml
sign=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= OTHER_CODE_SIGN_FLAGS=)

if [ "${1:-run}" = test ]; then
  xcodebuild -quiet -project SQLServerSetup.xcodeproj -scheme SQLServerSetup -destination 'platform=macOS' \
    -derivedDataPath build/dd "${sign[@]}" test
  echo "Tests passed."
else
  xcodebuild -quiet -project SQLServerSetup.xcodeproj -scheme SQLServerSetup -destination 'platform=macOS' \
    -configuration Debug -derivedDataPath build/dd "${sign[@]}" build
  open "build/dd/Build/Products/Debug/SQL Server Setup.app"
fi
