#!/bin/bash
# Builds dist/UzbekKeyboardSetup.zip: the Mac setup app. Like the Windows setup program it shows the
# Classic, Direct and Turkish-style layouts and installs the one the person picks, into their own
# ~/Library/Keyboard Layouts. The Mac layouts and their pictures are generated from the .klc files,
# so run this again after changing one. Needs macOS with Xcode.
set -euo pipefail
cd "$(dirname "$0")"

version=1.1.0
work=build/mac
app="$work/UzbekKeyboardSetup.app"

swift test --package-path mac
rm -rf "$work"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" dist

# One program for both Intel and Apple silicon Macs.
swift build --package-path mac -c release --arch arm64 --arch x86_64 --product UzbekKeyboardSetup
bin=$(swift build --package-path mac -c release --arch arm64 --arch x86_64 --show-bin-path)
cp "$bin/UzbekKeyboardSetup" "$app/Contents/MacOS/"

# What the app carries: the layout bundle it installs, a picture of each layout, and its icon.
swift run --package-path mac keylayouts bundle --version "$version" "$app/Contents/Resources"
swift run --package-path mac keylayouts pictures "$app/Contents/Resources"
swift run --package-path mac keylayouts app-icon "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>UzbekKeyboardSetup</string>
    <key>CFBundleIdentifier</key><string>io.github.discoveruz.uzbek-keyboard-setup</string>
    <key>CFBundleName</key><string>Uzbek Keyboard Setup</string>
    <key>CFBundleDisplayName</key><string>Uzbek Keyboard Setup</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$version</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Apple silicon Macs only run signed programs; an ad-hoc signature is enough for that. The app is not
# signed by a registered developer, so the first launch needs Open Anyway, like Run anyway on Windows.
codesign --force --sign - "$app"

rm -f dist/UzbekKeyboardSetup.zip
ditto -c -k --keepParent "$app" dist/UzbekKeyboardSetup.zip
echo "Done: dist/UzbekKeyboardSetup.zip"
