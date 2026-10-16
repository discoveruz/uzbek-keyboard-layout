@testable import UzbekKeyboardMac

/// One key press: the key map its modifiers select and the Mac key code.
typealias Press = (map: Int, code: Int)

extension Keylayout {
    /// Types key presses the way macOS runs a keylayout, including dead keys,
    /// so tests can check what a sequence types without installing anything.
    func type(_ presses: [Press]) -> String {
        var state = "none"
        var text = ""
        for (map, code) in presses {
            switch keyMaps[map][code] {
            case nil:
                if state != "none" { text += terminators[state] ?? "" }
                state = "none"
            case .output(let output)?:
                if state != "none" { text += terminators[state] ?? "" }
                text += output
                state = "none"
            case .action(let id)?:
                let whens = actions[id] ?? []
                var when = whens.first { $0.state == state }
                if when == nil {
                    // Not handled in this state: the state's terminator, then what the key does on its own.
                    text += terminators[state] ?? ""
                    when = whens.first { $0.state == "none" }
                }
                text += when?.output ?? ""
                state = when?.next ?? "none"
            }
        }
        return text
    }
}
