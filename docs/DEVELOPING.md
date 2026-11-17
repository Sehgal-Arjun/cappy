# Developing Cappy

Notes for building and publishing Cappy.

## Building

Needs macOS 13+ and Swift 5.10+ (the Xcode command line tools are enough). `make-dmg.sh` also needs Python 3.11+ (`brew install python`). Builds are for the build machine's chip only, so release from an Apple Silicon Mac.

```bash
./scripts/build-app.sh   # builds dist/Cappy.app
./scripts/make-dmg.sh    # builds the app and wraps it in dist/Cappy-<version>.dmg
```

`make-dmg.sh` sets up a local `.venv` with [dmgbuild](https://github.com/dmgbuild/dmgbuild) on first run. The window art comes from `scripts/make-dmg-background.py` and the app icon from `scripts/make-icon.py` (both need Pillow: `.venv/bin/pip install pillow`). Their output is committed, so you only need them to change the art. Icon positions in `scripts/dmg/settings.py` must match the background.

## Releasing

Cappy updates itself with [Sparkle](https://sparkle-project.org). Installed copies check `https://github.com/Sehgal-Arjun/cappy/releases/latest/download/appcast.xml` once a day.

1. Bump `CFBundleShortVersionString` **and** `CFBundleVersion` in `Resources/Info.plist` (Sparkle compares `CFBundleVersion`), merge to `main` and push.
2. From a clean `main` that matches GitHub, run `./scripts/release.sh [notes.md]`. It builds and signs the DMG, writes `appcast.xml` and creates the GitHub release with both attached. It refuses to run if the build number didn't go up or the tag already exists. Needs `gh` logged in.

**Only release through `release.sh`.** Installed copies read the feed from the *latest* release, so a release made by hand without `appcast.xml` stops every update.

Updates are signed with an EdDSA key kept in the login Keychain under the account `cappy` (created with `"$(./scripts/sparkle-tools.sh)/generate_keys" --account cappy`). The public half is `SUPublicEDKey` in `Info.plist`. **Back up the private key** with `"$(./scripts/sparkle-tools.sh)/generate_keys" --account cappy -x cappy-key.txt`, store the file somewhere safe and delete it: without the key, existing copies can't install any future update.
