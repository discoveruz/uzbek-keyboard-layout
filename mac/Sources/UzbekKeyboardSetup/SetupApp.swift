import AppKit
import Carbon
import SwiftUI
import UzbekKeyboardMac

@main
struct SetupApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @StateObject private var model = SetupModel()

    init() {
        // Run as FreshInputSources' helper: print the enabled layouts and quit, without a window.
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.first == FreshInputSources.flag {
            print(SystemInputSources().enabledLayouts(bundleID: BundleWriter.identifier).sorted().joined(separator: "\n"))
            exit(0)
        }
        // Developer aid, like the Windows setup's: saves the README pictures of the window instead of opening it.
        if arguments.count == 2, arguments[0] == "--render-images" {
            MainActor.assumeIsolated { renderImages(to: URL(fileURLWithPath: arguments[1])) }
            exit(0)
        }
    }

    var body: some Scene {
        Window(model.text.windowTitle, id: "setup") {
            SetupView(model: model)
                .frame(minWidth: 900, minHeight: 680)
        }
        .defaultSize(width: 1180, height: 820)
    }
}

/// A setup program: closing its only window quits it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opened from Finder or a download, the window should come to the front, not wait behind other apps.
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// The three layouts, in the order of the cards, with the picture each one shows.
let layouts = [
    (name: "Uzbek Latin 2026 (Classic)", picture: "classic"),
    (name: "Uzbek Latin 2026 (Direct)", picture: "direct"),
    (name: "Uzbek Latin 2026 (Turkish-style)", picture: "turkish-style"),
]

enum Theme {
    static let accent = Color(red: 0x0A / 255, green: 0x7C / 255, blue: 0x99 / 255)
    static let accentSoft = Color(red: 0x0A / 255, green: 0x7C / 255, blue: 0x99 / 255).opacity(0.12)
    static let changed = Color(red: 0xD6 / 255, green: 0xEE / 255, blue: 0xF5 / 255)
    static let ok = Color(red: 0x16 / 255, green: 0x80 / 255, blue: 0x3A / 255)
    static let bad = Color(red: 0xBF / 255, green: 0x26 / 255, blue: 0x30 / 255)
}

/// How a status message looks: done, a step for the person to take, or a failure.
enum StatusKind { case done, instruction, failed }

@MainActor
final class SetupModel: ObservableObject {
    @Published var text = Strings.uzbek
    @Published var selected = layouts[1].name
    @Published var installed: Set<String> = []
    @Published var status: (message: String, kind: StatusKind)?
    @Published var busy = false
    /// A layout the person was sent to System Settings to take out, until it is gone.
    var waitingForRemoval: String?
    let sources = FreshInputSources()
    let installer: LayoutInstaller?
    private var observer: NSObjectProtocol?

    /// `checkInstalled: false` shows no Installed badges, for the README pictures.
    init(checkInstalled: Bool = true) {
        installer = Bundle.main.url(forResource: "Uzbek Latin 2026", withExtension: "bundle").map { [sources] bundle in
            LayoutInstaller(bundle: bundle, folder: LayoutInstaller.forCurrentUser(bundle: bundle).folder,
                            systemFolder: URL(fileURLWithPath: "/Library/Keyboard Layouts"), sources: sources)
        }
        guard checkInstalled else { return }
        refresh()
        // macOS announces it when layouts are turned off, in System Settings or the input menu.
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func picture(_ layout: String) -> NSImage? {
        let name = layouts.first { $0.name == layout }?.picture
        return name.flatMap { Bundle.main.url(forResource: $0, withExtension: "png") }.flatMap(NSImage.init(contentsOf:))
    }

    func refresh() {
        Task {
            await sources.reload()
            installed = sources.enabled
            if let layout = waitingForRemoval, !installed.contains(layout) {
                waitingForRemoval = nil
                try? installer?.removeFilesIfUnused()
                status = (text.removed(layout), .done)
            }
        }
    }

    func install() {
        guard let installer else { status = (text.missingFiles, .failed); return }
        let layout = selected
        busy = true
        Task {
            await sources.reload()
            do {
                try installer.install(layout)
                status = (text.installedNow(layout), .done)
            } catch {
                status = (text.failed("\(error)"), .failed)
            }
            await sources.reload()
            installed = sources.enabled
            busy = false
        }
    }

    /// macOS doesn't reliably let apps turn layouts like these off, so Remove opens Keyboard settings
    /// and says what to click there; the badge and the files follow once the layout is gone.
    func remove() {
        waitingForRemoval = selected
        status = (text.removeInSettings(selected), .instruction)
        if let settings = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(settings)
        }
    }
}

struct SetupView: View {
    @ObservedObject var model: SetupModel

    var text: Strings { model.text }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text.heading).font(.system(size: 30, weight: .bold))
                    Text(text.intro).font(.system(size: 15)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Picker("", selection: Binding(get: { model.text.languageName }, set: { name in
                    model.text = Strings.all.first { $0.languageName == name } ?? .uzbek
                    model.status = nil
                })) {
                    ForEach(Strings.all, id: \.languageName) { Text($0.languageName).tag($0.languageName) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            HStack(spacing: 14) {
                ForEach(layouts, id: \.name) { layout in
                    LayoutCard(title: text.title(layout.name), summary: text.summary(layout.name),
                               badge: model.installed.contains(layout.name) ? text.badge : nil,
                               selected: model.selected == layout.name) {
                        model.selected = layout.name
                        model.status = nil
                    }
                }
            }
            // Cards as tall as the longest summary, no taller: the rest of the window goes to the picture.
            .fixedSize(horizontal: false, vertical: true)

            if let picture = model.picture(model.selected) {
                Image(nsImage: picture)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(text.title(model.selected))
            } else {
                Spacer()
            }

            Legend(text: text)

            HStack(spacing: 16) {
                if let status = model.status {
                    switch status.kind {
                    case .done:
                        Label(status.message, systemImage: "checkmark.circle.fill").foregroundStyle(Theme.ok)
                    case .instruction:
                        Label(status.message, systemImage: "arrow.right.circle.fill").foregroundStyle(Theme.accent)
                    case .failed:
                        Label(status.message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.bad)
                    }
                } else {
                    Text(text.afterInstallHint).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                let title = text.title(model.selected)
                if model.installed.contains(model.selected) {
                    Button(text.removeButton(title)) { model.remove() }
                        .buttonStyle(.link)
                        .disabled(model.busy)
                    Button(text.installedButton) {}
                        .disabled(true)
                        .controlSize(.large)
                } else {
                    Button(text.installButton(title)) { model.install() }
                        .disabled(model.busy)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .font(.system(size: 14))
        }
        .padding(28)
        .onAppear { model.refresh() }
        // Layouts may have been turned on or off in System Settings while the app was in the background.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refresh() }
    }
}

struct LayoutCard: View {
    let title: String
    let summary: String
    let badge: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(selected ? Theme.accent : .secondary)
                    Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(selected ? Theme.accent : .primary)
                    Spacer(minLength: 0)
                    if let badge {
                        Text(badge).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Theme.ok))
                    }
                }
                Text(summary).font(.system(size: 14)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 30)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Theme.accentSoft : Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Theme.accent : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

/// Explains the four corners of a key and the colors on the keyboard.
struct Legend: View {
    let text: Strings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 26) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(Color.white)
                    RoundedRectangle(cornerRadius: 7).strokeBorder(Color.secondary.opacity(0.4))
                    VStack {
                        HStack { Text(text.legendShift); Spacer(); Text(text.legendOptionShift).foregroundStyle(Color(white: 0.4)) }
                        Spacer()
                        HStack { Text(text.legendKey); Spacer(); Text(text.legendOption).foregroundStyle(Color(white: 0.4)) }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                }
                .frame(width: 140, height: 56)

                HStack(spacing: 8) {
                    Text("ö").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.accent)
                    Text(text.legendUzbekLetter)
                }
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.changed).frame(width: 18, height: 18)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.5)))
                    Text(text.legendChanged)
                }
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.accent, lineWidth: 2).frame(width: 18, height: 18)
                    Text(text.legendOptionKey)
                }
            }
            Text(text.otherOptionCharacters).foregroundStyle(.secondary)
        }
        .font(.system(size: 13))
    }
}

/// Text Input Sources, except that what is turned on comes from a fresh process: a running app's own
/// view of that list doesn't follow changes made in System Settings. The answer is kept between reloads,
/// and this app's own turning on and off updates it.
final class FreshInputSources: InputSources, @unchecked Sendable {
    static let flag = "--enabled-layouts"
    let system = SystemInputSources()
    @MainActor private(set) var enabled: Set<String> = []

    /// Asks a copy of this app, started with `flag`, which layouts are turned on.
    @MainActor func reload() async {
        enabled = await Task.detached {
            guard let executable = Bundle.main.executableURL else { return [] }
            let helper = Process()
            let output = Pipe()
            helper.executableURL = executable
            helper.arguments = [FreshInputSources.flag]
            helper.standardOutput = output
            guard (try? helper.run()) != nil else { return [] }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            helper.waitUntilExit()
            return Set(String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init))
        }.value
    }

    func register(bundle: URL) throws { try system.register(bundle: bundle) }
    func select(_ layout: String, bundleID: String) throws { try system.select(layout, bundleID: bundleID) }

    func enable(_ layout: String, bundleID: String) throws {
        try system.enable(layout, bundleID: bundleID)
        MainActor.assumeIsolated { _ = enabled.insert(layout) }
    }


    func enabledLayouts(bundleID: String) -> Set<String> {
        MainActor.assumeIsolated { enabled }
    }
}

/// Draws the window in each language, in light mode with Direct selected, as mac-setup-uz.png and mac-setup-en.png.
@MainActor
func renderImages(to folder: URL) {
    _ = NSApplication.shared
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for (language, file) in [(Strings.uzbek, "mac-setup-uz.png"), (Strings.english, "mac-setup-en.png")] {
        let model = SetupModel(checkInstalled: false)
        model.text = language
        let size = NSSize(width: 1100, height: 780)
        // Drawn as the active window, so the Install button and the language switch keep their colors.
        // An opaque window background: offscreen, it would otherwise be transparent, and the dark text
        // unreadable on GitHub's dark theme.
        let view = NSHostingView(rootView: SetupView(model: model).frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.controlActiveState, .key))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .windowBackgroundColor
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        // One pixel per point keeps the files about the size of the Windows pictures.
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
        bitmap.size = size
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent(file))
    }
}
