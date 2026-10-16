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
}
