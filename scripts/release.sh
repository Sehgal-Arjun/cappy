#!/usr/bin/env bash
# Publishes a release: builds the DMG, signs it for Sparkle, writes the update
# feed (appcast.xml) and creates the GitHub release with both attached.
#
#   ./scripts/release.sh [notes.md]
#
# Before running: bump CFBundleShortVersionString *and* CFBundleVersion in
# Resources/Info.plist (Sparkle compares CFBundleVersion), and merge to main.
# Needs the "cappy" Sparkle key in your login Keychain (generate_keys --account cappy).
set -euo pipefail

cd "$(dirname "$0")/.."
NOTES="${1:-}"
REPO="Sehgal-Arjun/cappy"
PLIST=Resources/Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
TAG="v$VERSION"

if [ "$(git branch --show-current)" != "main" ] || [ -n "$(git status --porcelain)" ]; then
    echo "Release from a clean main checkout." >&2
    exit 1
fi
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "$TAG already exists. Bump the version in $PLIST first." >&2
    exit 1
fi

./scripts/make-dmg.sh
DMG="dist/Cappy-$VERSION.dmg"

# generate_appcast signs every archive in the folder with the Keychain key and
# writes the feed. Only this release goes in: older ones stay on their own
# release pages, and Sparkle only needs the newest.
SPARKLE_BIN=$(./scripts/sparkle-tools.sh)
UPDATES=dist/updates
rm -rf "$UPDATES" && mkdir -p "$UPDATES"
cp "$DMG" "$UPDATES/"
"$SPARKLE_BIN/generate_appcast" --account cappy \
    --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
    --link "https://github.com/$REPO/releases/tag/$TAG" \
    "$UPDATES"

echo "Publishing $TAG (build $BUILD)…"
NOTES_ARGS=(--generate-notes)
[ -n "$NOTES" ] && NOTES_ARGS=(--notes-file "$NOTES")
gh release create "$TAG" "$DMG" "$UPDATES/appcast.xml" \
    --repo "$REPO" --target main --title "Cappy $VERSION" "${NOTES_ARGS[@]}"

echo "Released $TAG. Installed copies will pick it up on their next daily check."
