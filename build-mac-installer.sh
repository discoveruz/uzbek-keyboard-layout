#!/bin/bash
# Builds dist/UzbekKeyboardSetup.pkg: a Mac installer that puts the Classic, Direct and Turkish-style
# layouts into /Library/Keyboard Layouts. The Mac layouts are generated from the .klc files, so run
# this again after changing one. Needs macOS with Xcode or the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

version=1.1.0
identifier=io.github.discoveruz.keyboardlayout.uzbek-latin-2026
work=build/mac

swift test --package-path mac
rm -rf "$work"
mkdir -p "$work/payload" dist
swift run --package-path mac keylayouts bundle --version "$version" "$work/payload"

# A relocatable bundle makes Installer update a copy it finds elsewhere on the Mac (this build
# folder, say) instead of installing into /Library/Keyboard Layouts, so turn relocation off.
pkgbuild --analyze --root "$work/payload" "$work/components.plist"
plutil -replace 0.BundleIsRelocatable -bool NO "$work/components.plist"
pkgbuild --root "$work/payload" --component-plist "$work/components.plist" \
    --identifier "$identifier" --version "$version" \
    --install-location "/Library/Keyboard Layouts" "$work/UzbekLatin2026.pkg"
productbuild --distribution mac/installer/distribution.xml --resources mac/installer/resources \
    --package-path "$work" dist/UzbekKeyboardSetup.pkg

echo "Done: dist/UzbekKeyboardSetup.pkg"
