import AppKit

/// The menu-bar icon of every layout: white "UZ" on the setup program's teal (#0A7C99),
/// which reads on both light and dark menu bars.
enum Icon {
    /// The icon as .icns, in the sizes the menu bar and System Settings use.
    static func icns() throws -> Data {
        let fileManager = FileManager.default
        let iconset = fileManager.temporaryDirectory.appendingPathComponent("UZ-\(UUID().uuidString).iconset")
        let icns = iconset.deletingPathExtension().appendingPathExtension("icns")
        defer {
            try? fileManager.removeItem(at: iconset)
            try? fileManager.removeItem(at: icns)
        }
        try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
        for (file, pixels) in [("icon_16x16.png", 16), ("icon_16x16@2x.png", 32), ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64)] {
            try png(pixels: pixels).write(to: iconset.appendingPathComponent(file))
        }
        let iconutil = Process()
        iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        iconutil.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
        try iconutil.run()
        iconutil.waitUntilExit()
        guard iconutil.terminationStatus == 0 else {
            throw SystemLayoutError(description: "iconutil could not make the icon (exit code \(iconutil.terminationStatus)).")
        }
        return try Data(contentsOf: icns)
    }

    static func png(pixels: Int) throws -> Data {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0, bitsPerPixel: 0) else {
            throw SystemLayoutError(description: "Could not draw the \(pixels) px icon.")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let size = CGFloat(pixels)
        NSColor(srgbRed: 0x0A / 255, green: 0x7C / 255, blue: 0x99 / 255, alpha: 1).setFill()
        let badge = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: size / 32, dy: size / 32)
        NSBezierPath(roundedRect: badge, xRadius: size * 0.2, yRadius: size * 0.2).fill()
        let label = NSAttributedString(string: "UZ", attributes: [
            .font: NSFont.systemFont(ofSize: size * 0.5, weight: .bold),
            .foregroundColor: NSColor.white,
        ])
        let labelSize = label.size()
        label.draw(at: NSPoint(x: (size - labelSize.width) / 2, y: (size - labelSize.height) / 2))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw SystemLayoutError(description: "Could not save the \(pixels) px icon.")
        }
        return data
    }
}
