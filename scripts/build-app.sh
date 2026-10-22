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

codesign --force --deep --sign - --identifier com.avvamobile.notepadsharp "$APP"
codesign --verify --strict "$APP"
echo "Hazır: $APP"
