#!/usr/bin/env bash
# Builds Cappy.app and wraps it in a styled dist/Cappy-<version>.dmg, ready to send.
# The window layout comes from scripts/dmg/settings.py (via dmgbuild); the
# background art from scripts/make-dmg-background.py.
set -euo pipefail

cd "$(dirname "$0")/.."

# dmgbuild lives in a local venv so nothing is installed system-wide.
if [ ! -x .venv/bin/dmgbuild ]; then
    echo "Setting up .venv with dmgbuild…"
    python3 -m venv .venv
    .venv/bin/pip install --quiet dmgbuild==2.0.0
fi

./scripts/build-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DMG="dist/Cappy-$VERSION.dmg"
rm -f dist/Cappy-*.dmg

.venv/bin/dmgbuild -s scripts/dmg/settings.py -D app=dist/Cappy.app -D dmg_dir="$PWD/scripts/dmg" "Cappy" "$DMG" >/dev/null

echo "Made $DMG"
