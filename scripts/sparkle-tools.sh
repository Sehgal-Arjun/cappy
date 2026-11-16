#!/usr/bin/env bash
# Fetches Sparkle's command-line tools (generate_keys, sign_update,
# generate_appcast) into .tools/sparkle, matching the version in Package.swift.
# Prints the bin directory.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION=$(grep -o 'Sparkle", exact: "[0-9.]*"' Package.swift | grep -o '[0-9][0-9.]*')
DIR=".tools/sparkle-$VERSION"

if [ ! -x "$DIR/bin/generate_appcast" ]; then
    rm -rf "$DIR" && mkdir -p "$DIR"
    curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz" \
        | tar -xJ -C "$DIR"
fi

echo "$PWD/$DIR/bin"
