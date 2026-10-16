import Testing
@testable import UzbekKeyboardMac

// Key maps: 0 alone, 1 Shift, 2 Caps Lock, 3 Option, 4 Shift Option, 5 Caps Lock Option,
// 6 Command, 7 Command Option, 8 Command Shift Option, 9 Control.
@Suite struct USLayoutTests {
    let us: Keylayout

    init() throws {
        us = try USLayout.load()
    }

    @Test func lettersFollowTheModifiers() {
        #expect(us.type([(0, 8)]) == "c")
        #expect(us.type([(1, 8)]) == "C")
        #expect(us.type([(2, 8)]) == "C")
        #expect(us.type([(3, 8)]) == "ç")
        #expect(us.type([(4, 8)]) == "Ç")
    }

    @Test func capsLockMapsDifferFromShiftAndOption() {
        #expect(us.type([(2, 18)]) == "1")   // Caps Lock doesn't shift digits
        #expect(us.type([(5, 0)]) == "Å")    // Caps Lock Option capitalizes Option letters
        #expect(us.type([(5, 14)]) == "´")   // and has no accent keys
    }

    @Test func commandAndControlKeepUSCharacters() {
        #expect(us.type([(6, 8)]) == "c")
        #expect(us.type([(7, 0)]) == "å")
        #expect(us.type([(8, 0)]) == "Å")
        #expect(us.type([(9, 8)]) == "\u{03}")
        #expect(us.type([(7, 50)]) == "`")   // Command Option has no accent keys
    }

    @Test(arguments: [14, 32, 34, 45, 50])
    func optionAccentKeysWaitForTheNextKey(code: Int) {
        #expect(us.type([(3, code)]) == "")
    }

    @Test func accentKeysCombineWithLetters() {
        #expect(us.type([(3, 14), (0, 14)]) == "é")
        #expect(us.type([(3, 32), (0, 32)]) == "ü")
        #expect(us.type([(3, 50), (1, 0)]) == "À")
        #expect(us.type([(3, 45), (0, 45)]) == "ñ")
    }

    @Test func accentThenAnUnrelatedKeyTypesBoth() {
        #expect(us.type([(3, 14), (0, 12)]) == "´q")
    }

    @Test func keysWithoutCharactersAreKept() {
        #expect(us.type([(0, 36)]) == "\r")
        #expect(us.type([(0, 51)]) == "\u{08}")
        #expect(us.type([(0, 126)]) == "\u{1E}")
    }

    @Test func jisYenKeyIsKept() {
        #expect(us.type([(0, 93)]) == "¥")
    }
}
