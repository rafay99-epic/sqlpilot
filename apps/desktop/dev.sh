#!/bin/bash
# Debug build for development, ad-hoc signed (no Developer ID needed).
#   apps/desktop/dev.sh          # build and open the app
#   apps/desktop/dev.sh test     # run the unit tests
set -euo pipefail
cd "$(dirname "$0")"

[ -f build/AppIcon.icns ] || ../../assets/make-icon.sh install build/AppIcon.icns
xcodegen generate --quiet --spec project.yml
VERSION="0.$(git rev-list --count HEAD 2>/dev/null || echo 0)"
sign=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= OTHER_CODE_SIGN_FLAGS= MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$VERSION")

if [ "${1:-run}" = test ]; then
  xcodebuild -quiet -project SQLPilot.xcodeproj -scheme SQLPilot -destination 'platform=macOS' \
    -derivedDataPath build/dd "${sign[@]}" test
  echo "Tests passed."
else
  xcodebuild -quiet -project SQLPilot.xcodeproj -scheme SQLPilot -destination 'platform=macOS' \
    -configuration Debug -derivedDataPath build/dd "${sign[@]}" build
  open "build/dd/Build/Products/Debug/SQLPilot.app"
fi
