# Releasing ezNote

Everything is built and uploaded from a developer machine. There is no CI; never add a workflow that builds or publishes.

## Prerequisites

- macOS release machine with the Avva Mobile Developer ID Application certificate in the login keychain.
- App Store Connect API key (`AuthKey_<KEY_ID>.p8`), its Key ID and Issuer ID (for notarization).
- `gh` CLI signed in to an account with write access to `AvvaMobile/AvvaMobile.ezNote`.

## Steps

1. Bump `CFBundleShortVersionString` (and `CFBundleVersion`) in `scripts/Info.plist`, commit (`Sürüm X.Y.Z`). Do **not** push a tag.
2. `APPLE_API_KEY=~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 APPLE_API_KEY_ID=<KEY_ID> APPLE_API_ISSUER=<ISSUER_ID> scripts/release.sh`
   This builds a universal app (arm64 + x86_64), signs it with the hardened runtime, packs `build/ezNote-X.Y.Z.dmg`, notarizes and staples it, creates the draft release `vX.Y.Z` if needed and uploads the DMG.
3. Write the release notes in the draft, then publish it on GitHub.
4. Push the commit. GitHub creates the tag `vX.Y.Z` when the draft is published; run `git fetch --tags` afterwards. Never create or push the tag yourself.

## Local builds

- `scripts/build-app.sh` → `build/ezNote.app`, ad-hoc signed. Fine on the machine that built it; other Macs will refuse it. Builds never publish by themselves.

## Website

The site is `docs/index.html`, served by GitHub Pages from the `docs/` folder of `master`. Screenshots live in `docs/images/`.
