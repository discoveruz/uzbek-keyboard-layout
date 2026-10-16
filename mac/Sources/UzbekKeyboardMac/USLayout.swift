/// Apple's U.S. layout on this Mac, read through the ten key maps the Uzbek layouts use.
/// Every Uzbek layout starts as this copy, so all keys and modifiers the .klc files don't mention type
/// exactly what they do on a Mac with the U.S. layout, accent keys included.
public enum USLayout {
    /// Keyboard types for UCKeyTranslate: ANSI for every key, JIS for the keys only JIS keyboards have.
    static let ansiKeyboard: UInt32 = 40
    static let jisKeyboard: UInt32 = 42
    static let jisOnlyKeys = 93...95

    static func keyboard(for code: Int) -> UInt32 {
        jisOnlyKeys.contains(code) ? jisKeyboard : ansiKeyboard
    }

    public static func load() throws -> Keylayout {
        guard let source = SystemLayout.sources(id: "com.apple.keylayout.US").first else {
            throw SystemLayoutError(description: "This Mac has no U.S. keyboard layout (com.apple.keylayout.US).")
        }
        return try sample(SystemLayout(source: source))
    }

    static func sample(_ layout: SystemLayout) throws -> Keylayout {
        let maps = Keylayout.sampleModifiers.indices
        let codes = 0..<128
        func press(_ map: Int, _ code: Int, from state: UInt32 = 0) -> (output: String, state: UInt32) {
            layout.press(code, modifiers: Keylayout.sampleModifiers[map], state: state, keyboard: keyboard(for: code))
        }

        // What each key does on its own, and which keys start a dead-key state.
        let plain = maps.map { map in codes.map { press(map, $0) } }
        var starters: [UInt32: (map: Int, code: Int)] = [:]
        for map in maps {
            for code in codes where plain[map][code].state != 0 && starters[plain[map][code].state] == nil {
                starters[plain[map][code].state] = (map, code)
            }
        }
        func stateName(_ state: UInt32) throws -> String {
            guard starters[state] != nil else {
                throw SystemLayoutError(description: "The U.S. layout reached dead-key state \(state), which no key starts.")
            }
            return "dead\(state)"
        }

        // A dead state's terminator is what it types before a key it doesn't combine with, such as Q.
        var terminators: [String: String] = [:]
        for (state, starter) in starters {
            let entered = press(starter.map, starter.code).state
            let typed = press(0, 12, from: entered).output
            guard typed.hasSuffix("q") else {
                throw SystemLayoutError(description: "The U.S. layout combines dead-key state \(state) with Q.")
            }
            terminators[try stateName(state)] = String(typed.dropLast())
        }

        // Where a key does something other than "terminator, then its own output" after a dead key, record a `when`.
        var whens: [[Int: [When]]] = maps.map { _ in [:] }
        for (state, starter) in starters.sorted(by: { $0.key < $1.key }) {
            let name = try stateName(state)
            for map in maps {
                for code in codes {
                    let entered = press(starter.map, starter.code).state
                    let actual = press(map, code, from: entered)
                    let expected = (terminators[name]! + plain[map][code].output, plain[map][code].state)
                    if actual != expected {
                        whens[map][code, default: []].append(When(
                            state: name,
                            output: actual.output.isEmpty ? nil : actual.output,
                            next: actual.state == 0 ? nil : try stateName(actual.state)))
                    }
                }
            }
        }

        // Keys that start or combine with dead keys become actions; identical actions are shared.
        var keyMaps: [[Int: KeyEntry]] = maps.map { _ in [:] }
        var actions: [String: [When]] = [:]
        var actionIDs: [[When]: String] = [:]
        for map in maps {
            for code in codes {
                let (output, state) = plain[map][code]
                if state == 0 && whens[map][code] == nil {
                    if !output.isEmpty { keyMaps[map][code] = .output(output) }
                    continue
                }
                let action = [When(state: "none", output: output.isEmpty ? nil : output,
                                   next: state == 0 ? nil : try stateName(state))] + (whens[map][code] ?? [])
                let id = actionIDs[action] ?? "a\(actionIDs.count + 1)"
                actionIDs[action] = id
                actions[id] = action
                keyMaps[map][code] = .action(id)
            }
        }
        return Keylayout(name: "U.S.", id: 0, keyMaps: keyMaps, actions: actions, terminators: terminators)
    }
}
