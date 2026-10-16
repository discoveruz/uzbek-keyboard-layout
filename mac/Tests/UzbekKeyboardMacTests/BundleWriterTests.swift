import AppKit
import Foundation
import Testing
@testable import UzbekKeyboardMac

@Suite struct BundleWriterTests {
    let folder: URL
    let bundle: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("BundleWriterTests-\(UUID().uuidString)")
        bundle = try BundleWriter.write(try MacLayouts.build(klcFolder: repoRoot), version: "9.8.7", to: folder)
    }

    var resources: URL { bundle.appendingPathComponent("Contents/Resources") }

    func infoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: bundle.appendingPathComponent("Contents/Info.plist"))
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test func bundleIsNamedForTheKeyboardLayoutsFolder() {
        #expect(bundle.lastPathComponent == "Uzbek Latin 2026.bundle")
    }

    @Test(arguments: ["Uzbek Latin 2026 (Classic)", "Uzbek Latin 2026 (Direct)", "Uzbek Latin 2026 (Turkish-style)"])
    func eachLayoutHasItsFileIconAndUzbekLanguage(name: String) throws {
        let xml = try String(contentsOf: resources.appendingPathComponent("\(name).keylayout"), encoding: .utf8)
        #expect(xml.contains(#"name="\#(name)""#))
        #expect(FileManager.default.fileExists(atPath: resources.appendingPathComponent("\(name).icns").path))
        let info = try #require(try infoPlist()["KLInfo_\(name)"] as? [String: String])
        #expect(info["TISIntendedLanguage"] == "uz-Latn")
    }

    @Test func infoPlistCarriesTheBundleIDAndVersion() throws {
        let plist = try infoPlist()
        #expect(plist["CFBundleIdentifier"] as? String == "io.github.discoveruz.keyboardlayout.uzbek-latin-2026")
        #expect(plist["CFBundleVersion"] as? String == "9.8.7")
        #expect(plist["CFBundleShortVersionString"] as? String == "9.8.7")
    }

    @Test func iconHasMenuBarSizes() throws {
        let icon = try #require(NSImage(contentsOf: resources.appendingPathComponent("Uzbek Latin 2026 (Direct).icns")))
        let widths = Set(icon.representations.map(\.pixelsWide))
        #expect(widths.isSuperset(of: [16, 32, 64]))
    }

    @Test func buildSaysWhereToRunFromWhenTheKlcFilesAreMissing() throws {
        let empty = folder.appendingPathComponent("no-klc-here")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        let error = try #require(throws: KlcError.self) { try MacLayouts.build(klcFolder: empty) }
        #expect(error.description.contains("Uzbek-Latin-2026-Classic.klc"))
        #expect(error.description.contains("repo root"))
    }

    @Test func writingAgainReplacesTheOldBundle() throws {
        let stray = resources.appendingPathComponent("Old.keylayout")
        try Data().write(to: stray)
        _ = try BundleWriter.write(try MacLayouts.build(klcFolder: repoRoot), version: "9.8.7", to: folder)
        #expect(!FileManager.default.fileExists(atPath: stray.path))
    }
}
