import Testing
@testable import UzbekKeyboardMac

// Key maps: 0 alone, 1 Shift, 2 Caps Lock, 3 Option, 4 Shift Option, 5 Caps Lock Option,
// 6 Command, 7 Command Option, 8 Command Shift Option, 9 Control.
@Suite struct LayoutBuilderTests {
    let us: Keylayout
    let classic: Keylayout
    let direct: Keylayout
    let turkish: Keylayout

    init() throws {
        us = try USLayout.load()
        classic = LayoutBuilder.build(try loadKlc("Uzbek-Latin-2026-Classic.klc"), on: us, id: -26101)
        direct = LayoutBuilder.build(try loadKlc("Uzbek-Latin-2026-Direct.klc"), on: us, id: -26102)
        turkish = LayoutBuilder.build(try loadKlc("Uzbek-Latin-2026-Turkish-style.klc"), on: us, id: -26103)
    }

    @Test func takesNameAndIDFromTheKlc() {
        #expect(direct.name == "Uzbek Latin 2026 (Direct)")
        #expect(direct.id == -26102)
    }

    @Test func directCKeyTypesCCedillaButCommandCStillCopies() {
        #expect(direct.type([(0, 8)]) == "ç")
        #expect(direct.type([(1, 8)]) == "Ç")
        #expect(direct.type([(3, 8)]) == "c")
        #expect(direct.type([(6, 8)]) == "c")
        #expect(direct.type([(9, 8)]) == "\u{03}")
    }

    @Test func classicTypesUzbekLettersWithOption() {
        #expect(classic.type([(3, 31)]) == "ö")
        #expect(classic.type([(4, 31)]) == "Ö")
        #expect(classic.type([(3, 1)]) == "ş")
        #expect(classic.type([(3, 5)]) == "ğ")
        #expect(classic.type([(3, 39)]) == "\u{02BC}")
        #expect(classic.type([(4, 39)]) == "\u{02BB}")
    }

    @Test func unchangedKeysStillCombineWithAccentKeys() {
        #expect(classic.type([(3, 14), (0, 31)]) == "ó")
        #expect(direct.type([(3, 32), (0, 32)]) == "ü")
        #expect(turkish.type([(3, 45), (0, 45)]) == "ñ")
    }

    @Test func optionKeepsMacCharactersWhereTheKlcHasNothing() {
        #expect(direct.type([(3, 27)]) == "–")
        #expect(direct.type([(4, 27)]) == "—")
        #expect(classic.type([(3, 19)]) == "™")
    }

    @Test func turkishStyleMovesCommaToBackslashKey() {
        #expect(turkish.type([(0, 42)]) == ",")
        #expect(turkish.type([(1, 42)]) == ";")
        #expect(turkish.type([(0, 43)]) == "ç")
        #expect(turkish.type([(3, 43)]) == ",")
        #expect(turkish.type([(6, 42)]) == "\\")
        #expect(turkish.type([(6, 43)]) == ",")
    }

    @Test func capsLockFollowsTheKlcCapFlags() {
        #expect(direct.type([(2, 8)]) == "Ç")    // Cap 5: Caps Lock capitalizes ç
        #expect(direct.type([(2, 33)]) == "Ö")   // Cap 1
        #expect(turkish.type([(2, 42)]) == ",")  // Cap 0: comma stays a comma
        #expect(classic.type([(5, 31)]) == "Ö")  // Cap 5: also with Option
        #expect(direct.type([(5, 33)]) == "[")   // Cap 1: not with Option
    }

    @Test(arguments: [6, 7, 8, 9])
    func commandAndControlMapsStayUS(map: Int) {
        #expect(classic.keyMaps[map] == us.keyMaps[map])
        #expect(direct.keyMaps[map] == us.keyMaps[map])
        #expect(turkish.keyMaps[map] == us.keyMaps[map])
    }
}
