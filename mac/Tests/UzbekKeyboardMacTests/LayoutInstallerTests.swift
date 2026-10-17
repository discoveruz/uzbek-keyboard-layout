import Foundation
import Testing
@testable import UzbekKeyboardMac

/// Stands in for macOS's Text Input Sources, which tests must not change, and records what was asked of it.
final class RecordingInputSources: InputSources {
    var enabled: Set<String> = []
    var calls: [String] = []

    func register(bundle: URL) throws { calls.append("register \(bundle.lastPathComponent)") }
    func enabledLayouts(bundleID: String) -> Set<String> { enabled }
    func enable(_ layout: String, bundleID: String) throws { calls.append("enable \(layout)"); enabled.insert(layout) }
    func select(_ layout: String, bundleID: String) throws { calls.append("select \(layout)") }
}

@Suite struct LayoutInstallerTests {
    let home: URL
    let system: URL
    let shipped: URL
    let sources = RecordingInputSources()
    let installer: LayoutInstaller

    init() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Installer-\(UUID().uuidString)")
        home = root.appendingPathComponent("Keyboard Layouts")
        system = root.appendingPathComponent("System Keyboard Layouts")
        shipped = root.appendingPathComponent("App Resources/Uzbek Latin 2026.bundle")
        try FileManager.default.createDirectory(at: shipped.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: shipped.appendingPathComponent("Contents/Info.plist"))
        // Files unpacked from a downloaded zip carry the quarantine flag.
        _ = setxattr(shipped.appendingPathComponent("Contents/Info.plist").path, "com.apple.quarantine", "0081;00000000;Safari;", 21, 0, 0)
        installer = LayoutInstaller(bundle: shipped, folder: home, systemFolder: system, sources: sources)
    }

    var installedCopy: URL { home.appendingPathComponent("Uzbek Latin 2026.bundle") }

    @Test func installCopiesTheLayoutsAndTurnsOnTheChosenOne() throws {
        try installer.install("Uzbek Latin 2026 (Direct)")
        #expect(FileManager.default.fileExists(atPath: installedCopy.appendingPathComponent("Contents/Info.plist").path))
        #expect(sources.calls == ["register Uzbek Latin 2026.bundle", "enable Uzbek Latin 2026 (Direct)", "select Uzbek Latin 2026 (Direct)"])
        #expect(installer.isInstalled("Uzbek Latin 2026 (Direct)"))
        #expect(!installer.isInstalled("Uzbek Latin 2026 (Classic)"))
    }

    @Test func installedFilesLoseTheDownloadQuarantine() throws {
        try installer.install("Uzbek Latin 2026 (Direct)")
        let size = getxattr(installedCopy.appendingPathComponent("Contents/Info.plist").path, "com.apple.quarantine", nil, 0, 0, 0)
        #expect(size == -1)
    }

    @Test func installingAgainReplacesAnOlderCopy() throws {
        try FileManager.default.createDirectory(at: installedCopy.appendingPathComponent("Contents/Resources"), withIntermediateDirectories: true)
        try Data().write(to: installedCopy.appendingPathComponent("Contents/Resources/Old.keylayout"))
        try installer.install("Uzbek Latin 2026 (Classic)")
        #expect(!FileManager.default.fileExists(atPath: installedCopy.appendingPathComponent("Contents/Resources/Old.keylayout").path))
    }

    @Test func aLayoutMacOSAlreadyHasTurnedOnShowsAsInstalled() {
        // For example from an earlier install for all users.
        sources.enabled = ["Uzbek Latin 2026 (Direct)"]
        #expect(installer.isInstalled("Uzbek Latin 2026 (Direct)"))
    }

    @Test func aCopyForAllUsersIsUsedInsteadOfASecondOne() throws {
        try FileManager.default.createDirectory(at: system.appendingPathComponent("Uzbek Latin 2026.bundle"), withIntermediateDirectories: true)
        try installer.install("Uzbek Latin 2026 (Classic)")
        #expect(!FileManager.default.fileExists(atPath: installedCopy.path))
        #expect(sources.calls == ["enable Uzbek Latin 2026 (Classic)", "select Uzbek Latin 2026 (Classic)"])
    }

    @Test func installingATurnedOnLayoutOnlySwitchesToIt() throws {
        sources.enabled = ["Uzbek Latin 2026 (Direct)"]
        try FileManager.default.createDirectory(at: system.appendingPathComponent("Uzbek Latin 2026.bundle"), withIntermediateDirectories: true)
        try installer.install("Uzbek Latin 2026 (Direct)")
        #expect(sources.calls == ["select Uzbek Latin 2026 (Direct)"])
    }

    @Test func filesStayWhileALayoutIsStillOn() throws {
        try installer.install("Uzbek Latin 2026 (Direct)")
        try installer.removeFilesIfUnused()
        #expect(FileManager.default.fileExists(atPath: installedCopy.path))
    }

    @Test func filesGoOnceNoLayoutIsOn() throws {
        try installer.install("Uzbek Latin 2026 (Direct)")
        sources.enabled = []   // turned off in System Settings
        try installer.removeFilesIfUnused()
        #expect(!FileManager.default.fileExists(atPath: installedCopy.path))
    }
}
