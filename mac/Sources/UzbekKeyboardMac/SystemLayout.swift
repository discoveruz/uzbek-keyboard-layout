import Carbon
import Foundation

public struct SystemLayoutError: Error, CustomStringConvertible {
    public let description: String
}

/// HIToolbox aborts the process when two threads call Text Input Source functions at once
/// (tests run in parallel), so every TIS call goes through this lock.
private let textInputSources = NSLock()

/// A keyboard layout known to this Mac, read with UCKeyTranslate.
struct SystemLayout {
    let source: TISInputSource
    let data: CFData

    init(source: TISInputSource) throws {
        guard let pointer = textInputSources.withLock({ TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) }) else {
            throw SystemLayoutError(description: "The input source has no keyboard layout data.")
        }
        self.source = source
        data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
    }

    /// Runs Text Input Source calls one at a time (see `textInputSources`).
    static func withTextInputSources<T>(_ body: () throws -> T) rethrows -> T {
        try textInputSources.withLock(body)
    }

    /// The installed or enabled input sources with this ID.
    static func sources(id: String) -> [TISInputSource] {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        return textInputSources.withLock {
            TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
        }
    }

    /// The input sources a bundle provides (installed or enabled), with their IDs and names.
    static func sources(bundleID: String) -> [(id: String, name: String, source: TISInputSource)] {
        textInputSources.withLock {
            let all = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] ?? []
            return all.compactMap { source in
                guard string(source, kTISPropertyBundleID) == bundleID else { return nil }
                return (string(source, kTISPropertyInputSourceID) ?? "", string(source, kTISPropertyLocalizedName) ?? "", source)
            }
        }
    }

    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    /// What one key press types, starting from a dead-key state, and the state it leaves.
    func press(_ code: Int, modifiers: UInt32, state: UInt32 = 0, keyboard: UInt32) -> (output: String, state: UInt32) {
        var deadKeyState = state
        var length = 0
        var chars = [UniChar](repeating: 0, count: 16)
        let layout = UnsafePointer<UCKeyboardLayout>(OpaquePointer(CFDataGetBytePtr(data)!))
        UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDown), modifiers, keyboard, 0,
                       &deadKeyState, chars.count, &length, &chars)
        // After a composition UCKeyTranslate keeps the previous dead state in the high 16 bits;
        // the next key acts as if no dead key were pending, so only the low 16 bits are a state.
        return (String(utf16CodeUnits: chars, count: length), deadKeyState & 0xFFFF)
    }
}
