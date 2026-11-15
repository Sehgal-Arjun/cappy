#!/usr/bin/env bash
# Builds a release Cappy.app into dist/.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="dist/Cappy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$BIN_DIR/Cappy" "$APP/Contents/MacOS/Cappy"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Sparkle (auto-updates). ditto keeps the framework's symlinks intact.
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

# Everything else in Resources/ (sprites, icon) goes into the bundle as-is.
# Load these at runtime with Bundle.main, not SwiftPM's Bundle.module.
find Resources -mindepth 1 -maxdepth 1 ! -name Info.plist -exec cp -R {} "$APP/Contents/Resources/" \;

# Sign with CAPPY_SIGN_IDENTITY if set (e.g. your "Apple Development" cert),
# otherwise ad-hoc. Pinning the designated requirement to the bundle id keeps
# the app's identity the same across rebuilds, so login items and
# notification permissions survive updates.
IDENTITY="${CAPPY_SIGN_IDENTITY:--}"
# Sparkle's helpers (Autoupdate, Updater.app, XPC services) first, then the app.
codesign --force --deep --sign "$IDENTITY" "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign "$IDENTITY" \
    -r='designated => identifier "io.github.sehgal-arjun.cappy"' \
    "$APP"

echo "Built $APP"
