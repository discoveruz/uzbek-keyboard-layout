import Foundation

/// Checks the installed layouts key by key, the way macOS itself reads them. The expectation comes
/// straight from the .klc rules, not from LayoutBuilder: with Command or Control a key types what it
/// types on U.S.; otherwise the .klc decides wherever it has a character, and U.S. decides the rest.
public enum Verifier {
    /// UCKeyTranslate's modifier bits.
    static let command: UInt32 = 1, shift: UInt32 = 2, capsLock: UInt32 = 4, option: UInt32 = 8, control: UInt32 = 16
    static let deadKey = "(dead key)"
    static let nothing = "(nothing)"

    public struct Mismatch: Equatable, CustomStringConvertible {
        public let code: Int
        public let modifiers: UInt32
        public let expected: String
        public let actual: String

        public var description: String {
            "key \(code) with \(Verifier.name(modifiers)): expected \(expected.debugDescription), got \(actual.debugDescription)"
        }
    }

    /// Accent keys from the U.S. layout that every Uzbek layout keeps.
    static let accentSequences: [(keys: String, presses: [(code: Int, modifiers: UInt32)], typed: String)] = [
        ("⌥E E", [(14, option), (14, 0)], "é"),
        ("⌥U U", [(32, option), (32, 0)], "ü"),
        ("⌥I I", [(34, option), (34, 0)], "î"),
        ("⌥N N", [(45, option), (45, 0)], "ñ"),
        ("⌥` ⇧A", [(50, option), (0, shift)], "À"),
        ("⌥E Q", [(14, option), (12, 0)], "´q"),
    ]

    /// Checks every installed Uzbek layout; `passed` is false when one is missing or types something wrong.
    public static func run(klcFolder: URL) throws -> (passed: Bool, report: [String]) {
        guard let usSource = SystemLayout.sources(id: "com.apple.keylayout.US").first else {
            throw SystemLayoutError(description: "This Mac has no U.S. keyboard layout (com.apple.keylayout.US).")
        }
        let us = try SystemLayout(source: usSource)
        let installed = SystemLayout.sources(bundleID: BundleWriter.identifier)
        var passed = true
        var report: [String] = []
        for (file, _) in MacLayouts.all {
            let klc = try MacLayouts.loadKlc(file, from: klcFolder)
            guard let match = installed.first(where: { $0.name == klc.name }) else {
                passed = false
                report.append("\(klc.name): not found. Install it with the setup app (build/mac/UzbekKeyboardSetup.app) first.")
                continue
            }
            let layout = try SystemLayout(source: match.source)
            let mismatches = compare(layout, with: klc, us: us)
            let accentProblems = checkAccentKeys(layout)
            if mismatches.isEmpty && accentProblems.isEmpty {
                report.append("\(klc.name) [\(match.id)]: all \(32 * 128) key presses and \(accentSequences.count) accent sequences type what they should.")
            } else {
                passed = false
                report.append("\(klc.name) [\(match.id)]: \(mismatches.count) key presses and \(accentProblems.count) accent sequences are wrong:")
                report += mismatches.prefix(20).map { "  \($0)" } + accentProblems.map { "  \($0)" }
            }
        }
        return (passed, report)
    }

    /// Every key press, under every combination of Command, Shift, Caps Lock, Option and Control,
    /// where `installed` types something other than it should.
    static func compare(_ installed: SystemLayout, with klc: KlcLayout, us: SystemLayout) -> [Mismatch] {
        var mismatches: [Mismatch] = []
        for modifiers in UInt32(0)..<32 {
            for code in 0..<128 {
                let keyboard = USLayout.keyboard(for: code)
                let expected = expectedPress(klc.keys[code], modifiers: modifiers)
                    ?? describe(us.press(code, modifiers: modifiers, keyboard: keyboard))
                let actual = describe(installed.press(code, modifiers: modifiers, keyboard: keyboard))
                if expected != actual {
                    mismatches.append(Mismatch(code: code, modifiers: modifiers, expected: expected, actual: actual))
                }
            }
        }
        return mismatches
    }

    /// What the .klc says a key press types; nil where the U.S. layout decides.
    static func expectedPress(_ key: KlcKey?, modifiers: UInt32) -> String? {
        guard let key, modifiers & (command | control) == 0 else { return nil }
        let shifted = modifiers & shift != 0, caps = modifiers & capsLock != 0
        let character: String?
        if modifiers & option == 0 {
            // Shift wins over Caps Lock, as everywhere on a Mac.
            character = shifted || (caps && key.capsLock) ? key.shift : key.base
        } else if shifted {
            guard let altGrShift = key.altGrShift else { return nil }
            character = altGrShift
        } else if caps {
            guard key.altGr != nil || key.altGrShift != nil else { return nil }
            character = key.capsLockAltGr ? key.altGrShift : key.altGr
        } else {
            guard let altGr = key.altGr else { return nil }
            character = altGr
        }
        return character ?? nothing
    }

    static func describe(_ press: (output: String, state: UInt32)) -> String {
        press.state != 0 ? deadKey : press.output.isEmpty ? nothing : press.output
    }

    static func checkAccentKeys(_ layout: SystemLayout) -> [String] {
        accentSequences.compactMap { sequence in
            var state: UInt32 = 0
            var text = ""
            for press in sequence.presses {
                let result = layout.press(press.code, modifiers: press.modifiers, state: state, keyboard: USLayout.ansiKeyboard)
                text += result.output
                state = result.state
            }
            return text == sequence.typed ? nil : "\(sequence.keys) typed \(text.debugDescription), expected \(sequence.typed.debugDescription)"
        }
    }

    static func name(_ modifiers: UInt32) -> String {
        let names = [(command, "⌘"), (shift, "⇧"), (capsLock, "⇪"), (option, "⌥"), (control, "⌃")]
            .filter { modifiers & $0.0 != 0 }.map(\.1).joined()
        return names.isEmpty ? "no modifiers" : names
    }
}
