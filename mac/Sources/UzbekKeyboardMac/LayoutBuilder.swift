/// Builds a Mac layout from a .klc layout: Apple's U.S. layout with the .klc's characters on top.
/// Only the maps for the key alone, Shift, Caps Lock and Option change; Command and Control stay U.S.,
/// so shortcuts sit where they are on a US keyboard, as Windows keeps them through the .klc's VK column.
public enum LayoutBuilder {
    public static func build(_ klc: KlcLayout, on us: Keylayout, id: Int) -> Keylayout {
        var layout = us
        layout.name = klc.name
        layout.id = id
        for (code, key) in klc.keys {
            layout.set(map: 0, code: code, to: key.base)
            layout.set(map: 1, code: code, to: key.shift)
            layout.set(map: 2, code: code, to: key.capsLock ? key.shift : key.base)
            // Option is AltGr. Where the .klc has nothing on AltGr, the Mac's own Option characters stay.
            if let altGr = key.altGr {
                layout.set(map: 3, code: code, to: altGr)
            }
            if let altGrShift = key.altGrShift {
                layout.set(map: 4, code: code, to: altGrShift)
            }
            if key.altGr != nil || key.altGrShift != nil {
                layout.set(map: 5, code: code, to: key.capsLockAltGr ? key.altGrShift : key.altGr)
            }
        }
        return layout
    }
}

extension Keylayout {
    /// What a key types when no dead key is pending; nil when it types nothing.
    func plain(map: Int, code: Int) -> (output: String?, startsDeadKey: Bool) {
        switch keyMaps[map][code] {
        case nil:
            return (nil, false)
        case .output(let output)?:
            return (output, false)
        case .action(let id)?:
            let none = actions[id]?.first { $0.state == "none" }
            return (none?.output, none?.next != nil)
        }
    }

    /// Makes a key type `output` (nothing when nil). A key that already types it keeps its entry,
    /// so accent keys still combine with it.
    mutating func set(map: Int, code: Int, to output: String?) {
        let current = plain(map: map, code: code)
        if current.output == output && !current.startsDeadKey {
            return
        }
        keyMaps[map][code] = output.map { .output($0) }
    }
}
