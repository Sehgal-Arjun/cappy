#!/usr/bin/env bash
# Fetches Sparkle's command-line tools (generate_keys, sign_update,
# generate_appcast) into .tools/sparkle-<version>, matching Package.swift.
# The tarball is checked against a pinned SHA-256 before anything runs from it,
# since generate_appcast gets access to the signing key. Prints the bin directory.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION=$(grep -o 'Sparkle", exact: "[0-9.]*"' Package.swift | grep -o '[0-9][0-9.]*')

# Update both together when bumping Sparkle in Package.swift.
PINNED_VERSION="2.10.1"
PINNED_SHA256="1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27"

if [ "$VERSION" != "$PINNED_VERSION" ]; then
    echo "Package.swift uses Sparkle $VERSION but sparkle-tools.sh pins $PINNED_VERSION. Update the pin." >&2
    exit 1
fi

DIR=".tools/sparkle-$VERSION"
if [ ! -f "$DIR/.verified" ]; then
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    curl -fsSL -o "$TMP/sparkle.tar.xz" \
        "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz"
    ACTUAL=$(shasum -a 256 "$TMP/sparkle.tar.xz" | awk '{print $1}')
    if [ "$ACTUAL" != "$PINNED_SHA256" ]; then
        echo "Sparkle download checksum mismatch ($ACTUAL). Not using it." >&2
        exit 1
    fi
    mkdir -p "$TMP/out"
    tar -xJf "$TMP/sparkle.tar.xz" -C "$TMP/out"
    touch "$TMP/out/.verified"
    rm -rf "$DIR" && mkdir -p .tools && mv "$TMP/out" "$DIR"
fi

echo "$PWD/$DIR/bin"
