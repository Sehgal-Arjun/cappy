# Cappy

A tiny pixel cat in your menu bar that keeps your Mac awake.

Cappy is a friendly front end for macOS's built-in `caffeinate`. Pick how long, pick what to keep awake, and Cappy sits up in the menu bar until time's up, then curls up for a nap.

## Building

Needs macOS 13+ and Swift 5.10+ (the Xcode command line tools are enough).

```bash
./scripts/build-app.sh   # builds dist/Cappy.app
./scripts/make-dmg.sh    # builds the app and wraps it in dist/Cappy-<version>.dmg
```

The DMG has Cappy, a shortcut to Applications and a "Read me first" note with the steps below. Bump `CFBundleShortVersionString` in `Resources/Info.plist` for a new release.

The app icon is generated from the cat sprite with `python3 scripts/make-icon.py` (needs Pillow). The resulting `Resources/AppIcon.icns` is committed, so you only need this to change the icon.

## Opening it the first time

Cappy isn't notarized by Apple, so macOS blocks the first launch:

1. Drag Cappy into Applications and open it. macOS says it can't be opened. Click Done.
2. Open System Settings › Privacy & Security, scroll down, and click **Open Anyway** next to Cappy.
3. Confirm. From then on it opens normally.

## Credits

Code is MIT licensed. The cat sprites are by [Elthen](https://elthen.itch.io/2d-pixel-art-cat-sprites) and are used under their own licence, not MIT.
