#!/usr/bin/env bash
# Builds Cappy.app and wraps it in dist/Cappy.dmg, ready to send.
set -euo pipefail

cd "$(dirname "$0")/.."
./scripts/build-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp -R dist/Cappy.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "scripts/dmg/Read me first.txt" "$STAGE/"

DMG="dist/Cappy-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Cappy" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

echo "Made $DMG"
