/// What a key does in one key map: types text, or runs an action (a dead key, or a key a dead key combines with).
public enum KeyEntry: Equatable, Sendable {
    case output(String)
    case action(String)
}

/// One `when` of an action: in `state`, type `output`, then move to `next` (back to "none" when nil).
public struct When: Hashable, Sendable {
    public var state: String
    public var output: String?
    public var next: String?
}

/// A Mac keyboard layout (.keylayout) built from the ten key maps every Uzbek layout uses.
public struct Keylayout: Equatable, Sendable {
    public var name: String
    public var id: Int
    /// keyMaps[map][Mac key code]; see `modifierMaps` for what selects each map.
    public var keyMaps: [[Int: KeyEntry]]
    /// Action id to its `when` list.
    public var actions: [String: [When]]
    /// Dead-key state to what it types when the next key doesn't combine with it.
    public var terminators: [String: String]

    /// The `keys` of each key map's modifier rule. Together they cover every combination of
    /// Shift, Caps Lock, Option, Control and Command exactly once; Control is also the default.
    static let modifierMaps = [
        "",                                               // 0 the key alone
        "anyShift caps?",                                 // 1 Shift
        "caps",                                           // 2 Caps Lock
        "anyOption",                                      // 3 Option
        "anyShift caps? anyOption",                       // 4 Shift Option
        "caps anyOption",                                 // 5 Caps Lock Option
        "command anyShift? caps?",                        // 6 Command
        "command caps? anyOption",                        // 7 Command Option
        "command anyShift caps? anyOption",               // 8 Command Shift Option
        "anyControl anyShift? caps? anyOption? command?", // 9 Control
    ]
    static let defaultMap = 9

    /// One modifier combination per key map, in UCKeyTranslate's form
    /// (Command 1, Shift 2, Caps Lock 4, Option 8, Control 16).
    static let sampleModifiers: [UInt32] = [0, 2, 4, 8, 10, 12, 1, 9, 11, 16]
}

extension Keylayout {
    /// The layout as a .keylayout file. It is XML 1.1 because keys such as Return, and the Control map,
    /// type control characters, which only XML 1.1 can write (as character references).
    public func xml() -> String {
        let usedActions = Set(keyMaps.flatMap(\.values).compactMap { entry -> String? in
            if case .action(let id) = entry { return id }
            return nil
        })
        let actionIDs = usedActions.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let outputs = keyMaps.flatMap(\.values).compactMap { entry -> String? in
            if case .output(let output) = entry { return output }
            return nil
        } + actionIDs.flatMap { actions[$0, default: []].compactMap(\.output) } + terminators.values
        let maxout = outputs.map(\.utf16.count).max() ?? 1

        var lines = [
            #"<?xml version="1.1" encoding="UTF-8"?>"#,
            #"<!DOCTYPE keyboard SYSTEM "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">"#,
            "<!-- Generated from a .klc file by mac/keylayouts; change the .klc instead. -->",
            #"<keyboard group="126" id="\#(id)" name="\#(escaped(name))" maxout="\#(maxout)">"#,
            "    <layouts>",
            #"        <layout first="0" last="255" mapSet="ANSI" modifiers="Modifiers"/>"#,
            "    </layouts>",
            #"    <modifierMap id="Modifiers" defaultIndex="\#(Self.defaultMap)">"#,
        ]
        for (index, keys) in Self.modifierMaps.enumerated() {
            lines += [
                #"        <keyMapSelect mapIndex="\#(index)">"#,
                #"            <modifier keys="\#(keys)"/>"#,
                "        </keyMapSelect>",
            ]
        }
        lines += ["    </modifierMap>", #"    <keyMapSet id="ANSI">"#]
        for (index, keyMap) in keyMaps.enumerated() {
            lines.append(#"        <keyMap index="\#(index)">"#)
            for code in keyMap.keys.sorted() {
                switch keyMap[code]! {
                case .output(let output):
                    lines.append(#"            <key code="\#(code)" output="\#(escaped(output))"/>"#)
                case .action(let id):
                    lines.append(#"            <key code="\#(code)" action="\#(id)"/>"#)
                }
            }
            lines.append("        </keyMap>")
        }
        lines.append("    </keyMapSet>")
        if !actionIDs.isEmpty {
            lines.append("    <actions>")
            for id in actionIDs {
                lines.append(#"        <action id="\#(id)">"#)
                for when in actions[id, default: []] {
                    lines.append("            " + Self.whenElement(when))
                }
                lines.append("        </action>")
            }
            lines.append("    </actions>")
        }
        if !terminators.isEmpty {
            lines.append("    <terminators>")
            for state in terminators.keys.sorted() {
                lines.append("        " + Self.whenElement(When(state: state, output: terminators[state])))
            }
            lines.append("    </terminators>")
        }
        lines.append("</keyboard>")
        return lines.joined(separator: "\n") + "\n"
    }

    static func whenElement(_ when: When) -> String {
        var attributes = #"state="\#(when.state)""#
        if let output = when.output {
            attributes += #" output="\#(escaped(output))""#
        }
        if let next = when.next {
            attributes += #" next="\#(next)""#
        }
        return "<when \(attributes)/>"
    }
}

/// Text for an attribute value. Markup characters and control characters become character references,
/// the way Ukelele writes them; everything else stays as it is.
func escaped(_ text: String) -> String {
    var result = ""
    for scalar in text.unicodeScalars {
        switch scalar.value {
        case 0x26, 0x3C, 0x3E, 0x22, 0x27, 0..<0x20, 0x7F...0x9F:
            result += String(format: "&#x%04X;", scalar.value)
        default:
            result.unicodeScalars.append(scalar)
        }
    }
    return result
}
