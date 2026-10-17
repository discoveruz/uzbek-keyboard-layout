import Carbon
import Foundation

/// What the installer needs from macOS's Text Input Sources: layouts are named by their keylayout name.
public protocol InputSources {
    /// Tells macOS about a newly copied layout bundle, so it works without logging out.
    func register(bundle: URL) throws
    /// The bundle's layouts that are turned on (shown in the input menu).
    func enabledLayouts(bundleID: String) -> Set<String>
    func enable(_ layout: String, bundleID: String) throws
    /// Switches to the layout, so it is the one typing now.
    func select(_ layout: String, bundleID: String) throws
    // No disable: macOS acts on it late or only partly for layouts like these and leaves its own
    // lists disagreeing, so people take layouts out in System Settings, which keeps them consistent.
}

/// Installs layouts for the current user: copies the bundle the setup app carries into
/// ~/Library/Keyboard Layouts and turns the chosen layout on, with no password and no log-out.
public struct LayoutInstaller {
    public let bundle: URL
    public let folder: URL
    /// /Library/Keyboard Layouts: a copy there (from an install for all users) is used instead of adding a second one,
    /// since macOS can't turn on a layout whose name two copies share.
    public let systemFolder: URL
    public let sources: InputSources

    public init(bundle: URL, folder: URL, systemFolder: URL, sources: InputSources) {
        self.bundle = bundle
        self.folder = folder
        self.systemFolder = systemFolder
        self.sources = sources
    }

    /// The setup app's own copy of the layouts, installed into the user's Keyboard Layouts folder.
    public static func forCurrentUser(bundle: URL) -> LayoutInstaller {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Keyboard Layouts")
        return LayoutInstaller(bundle: bundle, folder: folder, systemFolder: URL(fileURLWithPath: "/Library/Keyboard Layouts"),
                               sources: SystemInputSources())
    }

    var installedCopy: URL { folder.appendingPathComponent(bundle.lastPathComponent) }
    var systemCopy: URL { systemFolder.appendingPathComponent(bundle.lastPathComponent) }

    /// Installed means macOS has the layout turned on, whichever copy of the layouts it comes from.
    public func isInstalled(_ layout: String) -> Bool {
        sources.enabledLayouts(bundleID: BundleWriter.identifier).contains(layout)
    }

    public func install(_ layout: String) throws {
        if !FileManager.default.fileExists(atPath: systemCopy.path) {
            try copyLayouts()
        }
        if !isInstalled(layout) {
            try sources.enable(layout, bundleID: BundleWriter.identifier)
        }
        try sources.select(layout, bundleID: BundleWriter.identifier)
    }

    func copyLayouts() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: installedCopy.path) {
            try fileManager.removeItem(at: installedCopy)
        }
        try fileManager.copyItem(at: bundle, to: installedCopy)
        // A zip downloaded from the web marks every file in it as quarantined, and copies keep the mark.
        // The layouts are plain data, so the installed copy goes without it.
        removeQuarantine(installedCopy)
        try sources.register(bundle: installedCopy)
    }

    /// Deletes this app's copy of the layouts once none of them is turned on.
    public func removeFilesIfUnused() throws {
        if sources.enabledLayouts(bundleID: BundleWriter.identifier).isEmpty,
           FileManager.default.fileExists(atPath: installedCopy.path) {
            try FileManager.default.removeItem(at: installedCopy)
        }
    }

    func removeQuarantine(_ url: URL) {
        removexattr(url.path, "com.apple.quarantine", XATTR_NOFOLLOW)
        guard let items = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { return }
        for case let item as URL in items {
            removexattr(item.path, "com.apple.quarantine", XATTR_NOFOLLOW)
        }
    }
}

/// The real Text Input Sources.
public struct SystemInputSources: InputSources {
    public init() {}

    public func register(bundle: URL) throws {
        let status = SystemLayout.withTextInputSources { TISRegisterInputSource(bundle as CFURL) }
        guard status == noErr else {
            throw SystemLayoutError(description: "macOS didn't accept the keyboard layouts (error \(status)).")
        }
    }

    public func enabledLayouts(bundleID: String) -> Set<String> {
        Set(SystemLayout.sources(bundleID: bundleID).filter { source in
            SystemLayout.withTextInputSources {
                guard let value = TISGetInputSourceProperty(source.source, kTISPropertyInputSourceIsEnabled) else { return false }
                return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue())
            }
        }.map(\.name))
    }

    public func enable(_ layout: String, bundleID: String) throws {
        try run(TISEnableInputSource, on: layout, bundleID: bundleID, doing: "turn on")
    }

    public func select(_ layout: String, bundleID: String) throws {
        try run(TISSelectInputSource, on: layout, bundleID: bundleID, doing: "switch to")
    }

    func run(_ action: (TISInputSource) -> OSStatus, on layout: String, bundleID: String, doing verb: String) throws {
        guard let source = SystemLayout.sources(bundleID: bundleID).first(where: { $0.name == layout })?.source else {
            throw SystemLayoutError(description: "macOS doesn't know \(layout) yet, so it couldn't \(verb) it.")
        }
        let status = SystemLayout.withTextInputSources { action(source) }
        guard status == noErr else {
            throw SystemLayoutError(description: "macOS couldn't \(verb) \(layout) (error \(status)).")
        }
    }
}
