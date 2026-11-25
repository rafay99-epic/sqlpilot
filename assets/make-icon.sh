#!/bin/bash
# Draws the app icon with icon.swift and packs it into an .icns.
#   assets/make-icon.sh <install|stack|ember> <out.icns>
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
variant=${1:-install}
out=$2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

swift "$here/icon.swift" "$variant" "$tmp/icon.png" 2>/dev/null
mkdir -p "$tmp/AppIcon.iconset" "$(dirname "$out")"
for s in 16 32 128 256 512; do
  sips -z $s $s "$tmp/icon.png" --out "$tmp/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$tmp/icon.png" --out "$tmp/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$tmp/AppIcon.iconset" -o "$out"
