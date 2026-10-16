import Foundation

/// What one key types in a .klc layout; nil where it types nothing.
public struct KlcKey: Equatable, Sendable {
    public var base: String?
    public var shift: String?
    public var altGr: String?
    public var altGrShift: String?
    /// Caps Lock works like Shift for the key alone (Cap flag 1).
    public var capsLock: Bool
    /// Caps Lock works like Shift with AltGr too (Cap flag 4).
    public var capsLockAltGr: Bool
}

public struct KlcError: Error, CustomStringConvertible {
    public let description: String

    init(_ description: String) {
        self.description = description
    }
}

/// A Windows layout in MSKLC's source format, reduced to what the Mac layouts need.
/// Parsing follows KlcParser in installer/Layouts.cs, but anything the Mac layouts
/// can't carry over (dead keys, ligatures, SGCaps, other keys) stops the build instead of being skipped.
public struct KlcLayout {
    /// The KBD description, which Windows shows as the layout's name.
    public let name: String
    /// Mac virtual key code to what the key types.
    public let keys: [Int: KlcKey]

    /// Keys the Mac layouts leave to Apple's U.S. layout, with what they must type in the .klc for that to be right.
    static let keysLeftToTheMac: [String: KlcKey] = [
        // The extra key next to left Shift on ISO keyboards.
        "56": KlcKey(base: "\\", shift: "|", altGr: nil, altGrShift: nil, capsLock: false, capsLockAltGr: false),
        // Keypad decimal point.
        "53": KlcKey(base: ".", shift: ".", altGr: nil, altGrShift: nil, capsLock: false, capsLockAltGr: false),
    ]

    public init(contentsOf url: URL) throws {
        // MSKLC writes UTF-16 with a byte order mark.
        try self.init(text: String(contentsOf: url, encoding: .utf16))
    }

    public init(text: String) throws {
        var name: String?
        var keys: [Int: KlcKey] = [:]
        var shiftStates: [Int] = []
        var section: String?
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.components(separatedBy: "//")[0].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") {
                continue
            }
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            if Self.isKeyword(parts[0]) {
                section = parts[0]
                if section == "KBD", let open = line.firstIndex(of: "\""), let close = line.lastIndex(of: "\""), open < close {
                    name = String(line[line.index(after: open)..<close])
                }
                continue
            }
            switch section {
            case "SHIFTSTATE":
                guard let state = Int(parts[0]) else { throw KlcError("Unreadable shift state: \(line)") }
                shiftStates.append(state)
            case "LAYOUT":
                let (scanCode, key) = try Self.parseKey(parts, shiftStates: shiftStates, line: line)
                if let code = MacKeyCodes.byScanCode[scanCode] {
                    keys[code] = key
                } else if let expected = Self.keysLeftToTheMac[scanCode] {
                    guard key == expected else {
                        throw KlcError("Key \(scanCode) changed, but the Mac layouts keep Apple's U.S. key there: \(line)")
                    }
                } else {
                    throw KlcError("Key \(scanCode) has no place in the Mac layouts: \(line)")
                }
            default:
                continue
            }
        }
        guard let name else { throw KlcError("No KBD line with the layout's name.") }
        self.name = name
        self.keys = keys
    }

    static func isKeyword(_ token: String) -> Bool {
        token.allSatisfy { ("A"..."Z").contains($0) || $0 == "_" }
    }

    static func parseKey(_ parts: [String], shiftStates: [Int], line: String) throws -> (String, KlcKey) {
        guard parts.count >= 3 + shiftStates.count else { throw KlcError("Too few columns: \(line)") }
        guard let cap = Int(parts[2]), [0, 1, 4, 5].contains(cap) else {
            throw KlcError("Unsupported Caps Lock column \(parts[2]): \(line)")
        }
        var key = KlcKey(base: nil, shift: nil, altGr: nil, altGrShift: nil, capsLock: cap & 1 != 0, capsLockAltGr: cap & 4 != 0)
        for (i, state) in shiftStates.enumerated() {
            let value = try decode(parts[3 + i], line: line)
            switch state {
            case 0: key.base = value
            case 1: key.shift = value
            case 6: key.altGr = value
            case 7: key.altGrShift = value
            default: break // Ctrl columns: the Mac layouts keep Apple's U.S. Control keys.
            }
        }
        return (parts[0].lowercased(), key)
    }

    static func decode(_ value: String, line: String) throws -> String? {
        if value == "-1" {
            return nil
        }
        // One character is the character itself, so a lone "@" is an at sign, not a dead-key mark.
        if value.count == 1 {
            return value
        }
        if value == "%%" {
            throw KlcError("Ligatures aren't supported on the Mac yet: \(line)")
        }
        if value.hasSuffix("@") {
            throw KlcError("Dead keys aren't supported on the Mac yet: \(line)")
        }
        guard let codePoint = UInt32(value, radix: 16), let scalar = Unicode.Scalar(codePoint) else {
            throw KlcError("Unreadable character \(value): \(line)")
        }
        return String(Character(scalar))
    }
}
