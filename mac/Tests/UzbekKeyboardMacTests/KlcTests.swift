import Foundation
import Testing
@testable import UzbekKeyboardMac

/// The repo root, where the three .klc files live.
let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

func loadKlc(_ file: String) throws -> KlcLayout {
    try KlcLayout(contentsOf: repoRoot.appendingPathComponent(file))
}

/// A minimal .klc with the same shift states as the real files and the given LAYOUT lines.
func klcText(_ layoutLines: String) -> String {
    """
    KBD\ttest\t"Test Layout"

    SHIFTSTATE

    0\t//Column 4
    1\t//Column 5 : Shft
    2\t//Column 6 :       Ctrl
    6\t//Column 7 :       Ctrl Alt
    7\t//Column 8 : Shft  Ctrl Alt

    LAYOUT\t\t;an extra '@' at the end is a dead key

    \(layoutLines)

    KEYNAME

    01\tEsc
    """
}

@Suite struct KlcTests {
    @Test func readsTheLayoutName() throws {
        #expect(try loadKlc("Uzbek-Latin-2026-Classic.klc").name == "Uzbek Latin 2026 (Classic)")
        #expect(try loadKlc("Uzbek-Latin-2026-Turkish-style.klc").name == "Uzbek Latin 2026 (Turkish-style)")
    }

    @Test(arguments: ["Uzbek-Latin-2026-Classic.klc", "Uzbek-Latin-2026-Direct.klc", "Uzbek-Latin-2026-Turkish-style.klc"])
    func everyMainKeyGetsItsOwnMacKey(file: String) throws {
        // 47 typing keys plus Space; two keys sharing a Mac key code would silently lose one.
        #expect(try loadKlc(file).keys.count == 48)
    }

    @Test func classicOKeyTypesUzbekLettersWithAltGr() throws {
        let o = try #require(try loadKlc("Uzbek-Latin-2026-Classic.klc").keys[31])
        #expect(o == KlcKey(base: "o", shift: "O", altGr: "ö", altGrShift: "Ö", capsLock: true, capsLockAltGr: true))
    }

    @Test func directLeftBracketKeyTypesOWithDiaeresis() throws {
        let bracket = try #require(try loadKlc("Uzbek-Latin-2026-Direct.klc").keys[33])
        #expect(bracket == KlcKey(base: "ö", shift: "Ö", altGr: "[", altGrShift: "{", capsLock: true, capsLockAltGr: false))
    }

    @Test func directRightBracketKeyTypesTheApostrophesWithAltGr() throws {
        let bracket = try #require(try loadKlc("Uzbek-Latin-2026-Direct.klc").keys[30])
        #expect(bracket.altGr == "\u{02BC}")
        #expect(bracket.altGrShift == "\u{02BB}")
    }

    @Test func turkishStyleBackslashKeyTypesComma() throws {
        let backslash = try #require(try loadKlc("Uzbek-Latin-2026-Turkish-style.klc").keys[42])
        #expect(backslash == KlcKey(base: ",", shift: ";", altGr: "\\", altGrShift: "|", capsLock: false, capsLockAltGr: false))
    }

    @Test func oneCharacterValuesAreLiteralAndLongerOnesAreHex() throws {
        let one = try #require(try loadKlc("Uzbek-Latin-2026-Classic.klc").keys[18])
        #expect(one.base == "1")
        #expect(one.shift == "!")
        let space = try #require(try loadKlc("Uzbek-Latin-2026-Classic.klc").keys[49])
        #expect(space.base == " ")
    }

    @Test func noneIsNil() throws {
        let a = try #require(try KlcLayout(text: klcText("1e\tA\t\t1\ta\tA\t-1\t-1\t-1")).keys[0])
        #expect(a == KlcKey(base: "a", shift: "A", altGr: nil, altGrShift: nil, capsLock: true, capsLockAltGr: false))
    }

    @Test func aLoneAtSignIsTheCharacterNotADeadKey() throws {
        let two = try #require(try KlcLayout(text: klcText("03\t2\t\t0\t2\t@\t-1\t-1\t-1")).keys[19])
        #expect(two.shift == "@")
    }

    @Test func rejectsDeadKeys() {
        #expect(throws: KlcError.self) { try KlcLayout(text: klcText("29\tOEM_3\t\t0\t0060@\t007e\t-1\t-1\t-1")) }
    }

    @Test func rejectsLigatures() {
        #expect(throws: KlcError.self) { try KlcLayout(text: klcText("1e\tA\t\t1\t%%\tA\t-1\t-1\t-1")) }
    }

    @Test func rejectsShiftGraphCaps() {
        #expect(throws: KlcError.self) { try KlcLayout(text: klcText("1e\tA\t\tSGCap\ta\tA\t-1\t-1\t-1")) }
        #expect(throws: KlcError.self) { try KlcLayout(text: klcText("1e\tA\t\t2\ta\tA\t-1\t-1\t-1")) }
    }

    @Test func rejectsKeysTheMacLayoutsCannotCarry() {
        #expect(throws: KlcError.self) { try KlcLayout(text: klcText("7e\tABNT_C2\t0\t002e\t002e\t-1\t-1\t-1")) }
    }

    @Test func leavesTheIsoKeyToTheMacOnlyWhileItIsUnchanged() throws {
        let unchanged = try KlcLayout(text: klcText("56\tOEM_102\t0\t005c\t007c\t001c\t-1\t-1"))
        #expect(unchanged.keys.isEmpty)
        #expect(throws: KlcError.self) { try KlcLayout(text: klcText("56\tOEM_102\t0\t002f\t007c\t001c\t-1\t-1")) }
    }
}
