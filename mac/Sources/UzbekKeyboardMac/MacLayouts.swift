import Foundation

/// The three layouts and the .klc files they come from; Catalog in installer/Layouts.cs lists the same three.
public enum MacLayouts {
    static let all: [(klc: String, id: Int)] = [
        ("Uzbek-Latin-2026-Classic.klc", -26101),
        ("Uzbek-Latin-2026-Direct.klc", -26102),
        ("Uzbek-Latin-2026-Turkish-style.klc", -26103),
    ]

    /// Builds every layout from the .klc files in `klcFolder`, on top of this Mac's U.S. layout.
    public static func build(klcFolder: URL) throws -> [Keylayout] {
        let us = try USLayout.load()
        return try all.map { layout in
            try LayoutBuilder.build(loadKlc(layout.klc, from: klcFolder), on: us, id: layout.id)
        }
    }

    /// Reads one of the .klc files. A missing file almost always means keylayouts runs in the wrong folder.
    static func loadKlc(_ file: String, from folder: URL) throws -> KlcLayout {
        let url = folder.appendingPathComponent(file)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw KlcError("Can't find \(file) in \(folder.path). Run keylayouts from the repo root, where the .klc files are.")
        }
        return try KlcLayout(contentsOf: url)
    }

    /// Writes a picture of each layout into `folder` as <prefix>classic.png, <prefix>direct.png and
    /// <prefix>turkish-style.png. The setup app uses scale 3, to stay sharp in its window; the README uses 1.
    public static func writePictures(klcFolder: URL, to folder: URL, scale: Int = 3, prefix: String = "") throws {
        let us = try USLayout.load()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for layout in all {
            let klc = try loadKlc(layout.klc, from: klcFolder)
            try KeyboardPicture.png(for: klc, us: us, scale: scale)
                .write(to: folder.appendingPathComponent("\(prefix)\(pictureName(klc.name)).png"))
        }
    }

    /// "Uzbek Latin 2026 (Turkish-style)" → "turkish-style".
    static func pictureName(_ layoutName: String) -> String {
        let variant = layoutName.split(separator: "(").last.map { $0.replacingOccurrences(of: ")", with: "") } ?? layoutName
        return variant.lowercased()
    }
}
