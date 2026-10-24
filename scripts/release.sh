#!/bin/zsh
# Builds ezNote, signs it with the Developer ID from the login keychain, notarizes and staples a DMG,
# then uploads it to the draft GitHub release of the Info.plist version (docs/RELEASING.md). No CI is involved.
# Needs APPLE_API_KEY (path to the .p8), APPLE_API_KEY_ID and APPLE_API_ISSUER.
set -euo pipefail
cd "${0:A:h}/.."
: "${APPLE_API_KEY:?path to AuthKey_XXXX.p8}" "${APPLE_API_KEY_ID:?}" "${APPLE_API_ISSUER:?}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" scripts/Info.plist)
TAG="v$VERSION"
IDENTITY=$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')
[[ -n "$IDENTITY" ]] || { echo "No Developer ID Application certificate in the keychain." >&2; exit 1; }

scripts/build-app.sh
APP=build/ezNote.app
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

DMG="build/ezNote-$VERSION.dmg"
STAGE=build/dmg
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "ezNote $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
codesign --sign "$IDENTITY" --timestamp "$DMG"

xcrun notarytool submit "$DMG" --key "$APPLE_API_KEY" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

gh release view "$TAG" >/dev/null 2>&1 || gh release create "$TAG" --draft --title "ezNote $VERSION" --notes "Release notes to be written."
gh release upload "$TAG" "$DMG" --clobber
echo "Uploaded $DMG to $TAG (draft). Write the notes and publish it from the GitHub Releases page."
