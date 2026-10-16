import Foundation
import Testing
@testable import UzbekKeyboardMac

// Modifier bits as UCKeyTranslate takes them: Command 1, Shift 2, Caps Lock 4, Option 8, Control 16.
@Suite struct VerifierTests {
    let us: SystemLayout

    init() throws {
        us = try SystemLayout(source: try #require(SystemLayout.sources(id: "com.apple.keylayout.US").first))
    }

    @Test func aLayoutWithNoKlcKeysMustTypeLikeUS() throws {
        #expect(Verifier.compare(us, with: try KlcLayout(text: klcText("")), us: us).isEmpty)
    }

    @Test func reportsWhereTheLayoutTypesSomethingElseThanTheKlc() throws {
        // Direct's C key, checked against plain U.S.: every non-Command, non-Control state differs.
        let klc = try KlcLayout(text: klcText("2e\tC\t\t5\t00e7\t00c7\t-1\t0063\t0043"))
        let mismatches = Verifier.compare(us, with: klc, us: us)
        let byModifiers = Dictionary(uniqueKeysWithValues: mismatches.map { ($0.modifiers, $0) })
        #expect(mismatches.allSatisfy { $0.code == 8 })
        #expect(byModifiers[0]?.expected == "ç")
        #expect(byModifiers[0]?.actual == "c")
        #expect(byModifiers[4]?.expected == "Ç")   // Cap 5: Caps Lock capitalizes
        #expect(byModifiers[8]?.expected == "c")
        #expect(byModifiers[12]?.expected == "C")  // Cap 5: also with Option
        #expect(Set(mismatches.map(\.modifiers)) == [0, 2, 4, 6, 8, 10, 12, 14])
    }

    @Test func verifySaysWhereToRunFromWhenTheKlcFilesAreMissing() throws {
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent("NoKlc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        let error = try #require(throws: KlcError.self) { try Verifier.run(klcFolder: empty) }
        #expect(error.description.contains("Uzbek-Latin-2026-Classic.klc"))
        #expect(error.description.contains("repo root"))
    }

    @Test func accentKeySequencesWorkOnUS() {
        #expect(Verifier.checkAccentKeys(us).isEmpty)
    }
}
