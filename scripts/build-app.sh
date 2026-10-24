#!/bin/zsh
# build/Notepad#.app paketini üretir (arm64 + x86_64, ad-hoc imzalı).
set -euo pipefail
cd "${0:A:h}/.."

ROOT=$PWD
APP="$ROOT/build/Notepad#.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swift build -c release --arch arm64 --arch x86_64
cp "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Notepad" "$APP/Contents/MacOS/Notepad"
cp scripts/Info.plist "$APP/Contents/Info.plist"

ICONSET=$ROOT/build/AppIcon.iconset
rm -rf "$ICONSET"
swift scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

codesign --force --deep --sign - --identifier com.avvamobile.notepadsharp "$APP"
codesign --verify --strict "$APP"
echo "Hazır: $APP"
