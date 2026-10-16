import Foundation
import Testing
@testable import UzbekKeyboardMac

/// A layout with the given entries in the key-alone map and nothing else.
func tinyLayout(_ entries: [Int: KeyEntry], actions: [String: [When]] = [:], terminators: [String: String] = [:]) -> Keylayout {
    var maps = Array(repeating: [Int: KeyEntry](), count: 10)
    maps[0] = entries
    return Keylayout(name: "Tiny", id: -1, keyMaps: maps, actions: actions, terminators: terminators)
}

/// Validates keylayout XML against Apple's DTD. libxml2 has no XML 1.1, so the control characters
/// that need 1.1 are swapped for private-use ones and the file is read as 1.0.
func validateAgainstAppleDTD(_ xml: String) throws {
    let asXML10 = xml
        .replacingOccurrences(of: "<?xml version=\"1.1\"", with: "<?xml version=\"1.0\"")
        .replacingOccurrences(of: "&#x00", with: "&#xE0")
    let document = try XMLDocument(xmlString: asXML10, options: [.nodeLoadExternalEntitiesAlways])
    try document.validate()
}

@Suite struct KeylayoutXMLTests {
    @Test func markupAndControlCharactersBecomeReferences() {
        let xml = tinyLayout([0: .output("&"), 1: .output("<"), 2: .output("\""), 3: .output("\u{03}"), 4: .output("é")]).xml()
        #expect(xml.contains(#"<key code="0" output="&#x0026;"/>"#))
        #expect(xml.contains(#"<key code="1" output="&#x003C;"/>"#))
        #expect(xml.contains(#"<key code="2" output="&#x0022;"/>"#))
        #expect(xml.contains(#"<key code="3" output="&#x0003;"/>"#))
        #expect(xml.contains(#"<key code="4" output="é"/>"#))
    }

    @Test func maxoutIsTheLongestOutput() {
        let xml = tinyLayout([0: .output("a"), 1: .action("a1")],
                             actions: ["a1": [When(state: "none", output: "b"), When(state: "dead1", output: "xyz")]],
                             terminators: ["dead1": "´"]).xml()
        #expect(xml.contains(#"maxout="3""#))
    }

    @Test func onlyActionsSomeKeyUsesAreWritten() {
        let xml = tinyLayout([0: .action("a1")],
                             actions: ["a1": [When(state: "none", output: "a")], "a2": [When(state: "none", output: "b")]]).xml()
        #expect(xml.contains(#"<action id="a1">"#))
        #expect(!xml.contains(#"<action id="a2">"#))
    }

    @Test(arguments: ["Uzbek-Latin-2026-Classic.klc", "Uzbek-Latin-2026-Direct.klc", "Uzbek-Latin-2026-Turkish-style.klc"])
    func generatedLayoutsMatchApplesDTD(file: String) throws {
        let layout = LayoutBuilder.build(try loadKlc(file), on: try USLayout.load(), id: -26100)
        try validateAgainstAppleDTD(layout.xml())
    }
}
