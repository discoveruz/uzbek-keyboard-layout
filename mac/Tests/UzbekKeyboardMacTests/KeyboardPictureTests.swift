import AppKit
import Testing
@testable import UzbekKeyboardMac

@Suite struct KeyboardPictureTests {
    let us: Keylayout
    let classic: KlcLayout
    let direct: KlcLayout

    init() throws {
        us = try USLayout.load()
        classic = try loadKlc("Uzbek-Latin-2026-Classic.klc")
        direct = try loadKlc("Uzbek-Latin-2026-Direct.klc")
    }

    func cap(_ code: Int, in klc: KlcLayout) throws -> KeyCap {
        try #require(KeyboardPicture.rows(for: klc, us: us).joined().first { $0.code == code })
    }

    @Test func everyRowIsFifteenKeysWide() {
        for row in KeyboardPicture.rows(for: direct, us: us) {
            #expect(row.map(\.width).reduce(0, +) == 15)
        }
    }

    @Test func directLeftBracketShowsTheUzbekLetterAndTheMovedBracket() throws {
        let bracket = try cap(33, in: direct)
        #expect(bracket.chars == ["ö", "Ö", "[", "{"])
        #expect(bracket.changed)
    }

    @Test func optionCharactersAreOnlyTheLayoutsOwn() throws {
        let s = try cap(1, in: direct)          // ß on Mac U.S., nothing in the .klc
        #expect(s.chars == ["s", "S", nil, nil])
        #expect(!s.changed)
        let o = try cap(31, in: classic)
        #expect(o.chars == ["o", "O", "ö", "Ö"])
        #expect(!o.changed)                     // the key alone still types o, as on U.S.
    }

    @Test func bothOptionKeysAreMarkedAndModifiersHaveMacNames() {
        let labels = KeyboardPicture.rows(for: direct, us: us)[4].compactMap(\.label)
        #expect(labels.filter { $0 == "option" }.count == 2)
        #expect(labels.contains("command") && labels.contains("control") && labels.contains("fn"))
        #expect(KeyboardPicture.rows(for: direct, us: us)[4].filter(\.isOption).count == 2)
    }

    @Test func largerScalesDrawMorePixels() throws {
        let bitmap = try #require(NSBitmapImageRep(data: try KeyboardPicture.png(for: direct, us: us, scale: 3)))
        #expect(bitmap.pixelsWide == KeyboardPicture.pixelSize.width * 3)
        #expect(bitmap.pixelsHigh == KeyboardPicture.pixelSize.height * 3)
    }

    @Test func changedKeysAreTintedInThePicture() throws {
        let picture = try KeyboardPicture.png(for: direct, us: us)
        let bitmap = try #require(NSBitmapImageRep(data: picture))
        #expect(bitmap.pixelsWide == KeyboardPicture.pixelSize.width)
        #expect(bitmap.pixelsHigh == KeyboardPicture.pixelSize.height)
        // A clear spot low in the middle of a key face: tinted for the changed [ key, plain for P.
        func face(_ code: Int) throws -> NSColor {
            let rect = try #require(KeyboardPicture.faceRect(code: code, in: KeyboardPicture.rows(for: direct, us: us)))
            return try #require(bitmap.colorAt(x: Int(rect.midX), y: Int(rect.minY + rect.height * 0.8)))
        }
        #expect(try face(33).usingColorSpace(.sRGB)!.isClose(to: KeyboardPicture.Colors.changed))
        #expect(try face(35).usingColorSpace(.sRGB)!.isClose(to: KeyboardPicture.Colors.key))
    }
}

extension NSColor {
    func isClose(to other: NSColor) -> Bool {
        guard let a = usingColorSpace(.sRGB), let b = other.usingColorSpace(.sRGB) else { return false }
        return abs(a.redComponent - b.redComponent) < 0.03 && abs(a.greenComponent - b.greenComponent) < 0.03
            && abs(a.blueComponent - b.blueComponent) < 0.03
    }
}
