#!/usr/bin/env bash
# Builds a release Cappy.app into dist/.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Cappy"

APP="dist/Cappy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/Cappy"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Everything else in Resources/ (sprites, icon) goes into the bundle as-is.
# Load these at runtime with Bundle.main, not SwiftPM's Bundle.module.
find Resources -mindepth 1 -maxdepth 1 ! -name Info.plist -exec cp -R {} "$APP/Contents/Resources/" \;

# Sign with CAPPY_SIGN_IDENTITY if set (e.g. your "Apple Development" cert),
# otherwise ad-hoc. Pinning the designated requirement to the bundle id keeps
# the app's identity the same across rebuilds, so login items and
# notification permissions survive updates.
IDENTITY="${CAPPY_SIGN_IDENTITY:--}"
codesign --force --sign "$IDENTITY" \
    -r='designated => identifier "io.github.sehgal-arjun.cappy"' \
    "$APP"

echo "Built $APP"
