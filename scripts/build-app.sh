#!/bin/zsh
# Builds, bundles, signs and installs Tiny Hands.app.
# Usage: scripts/build-app.sh [--install]
# SIGN_IDENTITY defaults to "-" (ad-hoc). Set it to a "Developer ID Application: …" identity to sign for distribution.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
IDENTITY=${SIGN_IDENTITY:--}
APP="$ROOT/build/Tiny Hands.app"

swift build -c release
BIN=$(swift build -c release --show-bin-path)/TinyHands

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TinyHands"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources/Pointers"
cp Resources/Pointers/*.svg "$APP/Contents/Resources/Pointers/"
mkdir -p "$APP/Contents/Resources/Sounds"
cp Resources/Sounds/*.wav Resources/Sounds/LICENSE.txt "$APP/Contents/Resources/Sounds/"

# Icon
ICONDIR=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONDIR"
swift scripts/make-icon.swift Resources/Pointers/app-icon.svg "$ICONDIR/icon_512x512@2x.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICONDIR/icon_512x512@2x.png" --out "$ICONDIR/icon_${s}x${s}.png" >/dev/null
  d=$((s*2)); sips -z $d $d "$ICONDIR/icon_512x512@2x.png" --out "$ICONDIR/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONDIR" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --options runtime --timestamp=none --sign "$IDENTITY" \
  --identifier com.tinyhands.TinyHands "$APP"
codesign --verify --strict --verbose=2 "$APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x TinyHands 2>/dev/null || true
  sleep 0.5
  rm -rf "/Applications/Tiny Hands.app"
  ditto "$APP" "/Applications/Tiny Hands.app"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/Tiny Hands.app"
  open "/Applications/Tiny Hands.app"
  echo "Installed to /Applications/Tiny Hands.app"
fi
