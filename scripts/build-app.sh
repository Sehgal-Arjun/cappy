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
find Resources -mindepth 1 -maxdepth 1 ! -name Info.plist -exec cp -R {} "$APP/Contents/Resources/" \;

# Ad-hoc signature: enough for macOS to run it locally and keep a stable identity.
codesign --force --sign - "$APP"

echo "Built $APP"
