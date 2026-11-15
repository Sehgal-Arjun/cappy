#!/usr/bin/env bash
# Publishes a release: builds the DMG, signs it for Sparkle, writes the update
# feed (appcast.xml) and creates the GitHub release with both attached.
#
#   ./scripts/release.sh [notes.md]
#
# Before running: bump CFBundleShortVersionString *and* CFBundleVersion in
# Resources/Info.plist (Sparkle compares CFBundleVersion), merge to main and push.
# Needs the "cappy" Sparkle key in your login Keychain (generate_keys --account cappy).
#
# Always release through this script: installed copies read the feed from the
# *latest* release, so a release without appcast.xml stops all updates.
set -euo pipefail

cd "$(dirname "$0")/.."
NOTES="${1:-}"
REPO="Sehgal-Arjun/cappy"
PLIST=Resources/Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
TAG="v$VERSION"

fail() { echo "$*" >&2; exit 1; }

# 1. Build exactly what's on GitHub's main.
[ "$(git branch --show-current)" = "main" ] || fail "Release from the main branch."
[ -z "$(git status --porcelain)" ] || fail "Commit or stash your changes first."
git fetch --quiet origin main
COMMIT=$(git rev-parse HEAD)
[ "$COMMIT" = "$(git rev-parse origin/main)" ] || fail "Local main isn't the same as origin/main. Push or pull first."

# 2. Don't reuse a version or a tag.
gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1 && fail "Release $TAG already exists. Bump the version in $PLIST."
[ -z "$(git ls-remote --tags origin "refs/tags/$TAG")" ] || fail "Tag $TAG already exists on GitHub. Bump the version or delete the stray tag."

# 3. The build number must go up, or Sparkle silently sees no update.
LATEST_BUILD=$(curl -fsL "https://github.com/$REPO/releases/latest/download/appcast.xml" 2>/dev/null \
    | grep -o '<sparkle:version>[0-9]*</sparkle:version>' | grep -o '[0-9]\+' | sort -n | tail -1 || true)
if [ -n "$LATEST_BUILD" ] && [ "$BUILD" -le "$LATEST_BUILD" ]; then
    fail "CFBundleVersion is $BUILD but the latest release is build $LATEST_BUILD. Bump it in $PLIST."
fi

./scripts/make-dmg.sh
DMG="dist/Cappy-$VERSION.dmg"

# generate_appcast signs every archive in the folder with the Keychain key and
# writes the feed. Only this release goes in: Sparkle only needs the newest.
SPARKLE_BIN=$(./scripts/sparkle-tools.sh)
UPDATES=dist/updates
rm -rf "$UPDATES" && mkdir -p "$UPDATES"
cp "$DMG" "$UPDATES/"
"$SPARKLE_BIN/generate_appcast" --account cappy \
    --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
    --link "https://github.com/$REPO/releases/tag/$TAG" \
    "$UPDATES"
grep -q "<sparkle:version>$BUILD</sparkle:version>" "$UPDATES/appcast.xml" \
    || fail "appcast.xml doesn't list build $BUILD; not publishing."

echo "Publishing $TAG (build $BUILD) at ${COMMIT:0:7}…"
NOTES_ARGS=(--generate-notes)
[ -n "$NOTES" ] && NOTES_ARGS=(--notes-file "$NOTES")
gh release create "$TAG" "$DMG" "$UPDATES/appcast.xml" \
    --repo "$REPO" --target "$COMMIT" --latest --title "Cappy $VERSION" "${NOTES_ARGS[@]}"

echo "Released $TAG. Installed copies will pick it up on their next daily check."
