import Foundation

/// Writes the layouts as one keyboard layout bundle, which the setup app installs into ~/Library/Keyboard Layouts.
public enum BundleWriter {
    public static let name = "Uzbek Latin 2026"
    public static let identifier = "io.github.discoveruz.keyboardlayout.uzbek-latin-2026"
    /// System Settings lists the layouts under this language.
    static let language = "uz-Latn"

    /// Writes "Uzbek Latin 2026.bundle" into `folder`, replacing any older copy, and returns its URL.
    public static func write(_ layouts: [Keylayout], version: String, to folder: URL) throws -> URL {
        let bundle = folder.appendingPathComponent("\(name).bundle")
        let resources = bundle.appendingPathComponent("Contents/Resources")
        if FileManager.default.fileExists(atPath: bundle.path) {
            try FileManager.default.removeItem(at: bundle)
        }
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

        let icon = try Icon.icns()
        var info: [String: Any] = [
            "CFBundleIdentifier": identifier,
            "CFBundleName": name,
            "CFBundleVersion": version,
            "CFBundleShortVersionString": version,
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundlePackageType": "BNDL",
        ]
        // macOS pairs each .keylayout with the .icns of the same name and with KLInfo_<layout name>.
        // It makes up the input source IDs itself (<bundle ID>.keylayout.<name>), so KLInfo only sets the language.
        for layout in layouts {
            try Data(layout.xml().utf8).write(to: resources.appendingPathComponent("\(layout.name).keylayout"))
            try icon.write(to: resources.appendingPathComponent("\(layout.name).icns"))
            info["KLInfo_\(layout.name)"] = ["TISIntendedLanguage": language]
        }
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: bundle.appendingPathComponent("Contents/Info.plist"))
        return bundle
    }
}
