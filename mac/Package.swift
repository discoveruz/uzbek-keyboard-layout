// swift-tools-version: 6.0
// Builds the Mac versions of the Uzbek Latin 2026 layouts from the .klc files in the repo root.
// Run it through build-mac-installer.sh; `swift test` checks the layout rules.
import PackageDescription

let package = Package(
    name: "UzbekKeyboardMac",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "UzbekKeyboardMac"),
        .executableTarget(name: "keylayouts", dependencies: ["UzbekKeyboardMac"]),
        .testTarget(name: "UzbekKeyboardMacTests", dependencies: ["UzbekKeyboardMac"]),
    ],
    swiftLanguageModes: [.v5]
)
