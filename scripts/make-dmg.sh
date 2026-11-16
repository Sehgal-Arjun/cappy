#!/usr/bin/env bash
# Builds Cappy.app and wraps it in a styled dist/Cappy-<version>.dmg, ready to send.
# The window layout comes from scripts/dmg/settings.py (via dmgbuild); the
# background art from scripts/make-dmg-background.py.
set -euo pipefail

cd "$(dirname "$0")/.."

# dmgbuild lives in a local venv so nothing is installed system-wide.
# It needs Python 3.11+; the Command Line Tools only ship 3.9.
if ! .venv/bin/python -c "import dmgbuild" 2>/dev/null; then
    if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null; then
        echo "make-dmg needs Python 3.11 or newer (found $(python3 --version 2>&1))." >&2
        echo "Install one with: brew install python" >&2
        exit 1
    fi
    echo "Setting up .venv with dmgbuild…"
    rm -rf .venv
    python3 -m venv .venv
    .venv/bin/pip install --quiet dmgbuild==2.0.0
fi

./scripts/build-app.sh

# An old Cappy disk still mounted would make dmgbuild use "/Volumes/Cappy 1"
# and bake that path into the window settings.
for vol in /Volumes/Cappy*; do
    [ -d "$vol" ] && hdiutil detach "$vol" -quiet && echo "Ejected $vol"
done

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DMG="dist/Cappy-$VERSION.dmg"
rm -f dist/Cappy-*.dmg

.venv/bin/dmgbuild -s scripts/dmg/settings.py \
    -D app=dist/Cappy.app -D dmg_dir="$PWD/scripts/dmg" \
    "Cappy" "$DMG" >/dev/null

echo "Made $DMG"
