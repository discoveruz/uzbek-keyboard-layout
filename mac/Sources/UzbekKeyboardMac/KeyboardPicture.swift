import AppKit

/// One key in a keyboard picture: a character key with what it types alone, with Shift, with Option
/// and with Option+Shift, or a key that only has a name (return, option, …).
struct KeyCap: Equatable {
    var code: Int?
    var label: String?
    var width: Double
    var chars: [String?] = [nil, nil, nil, nil]
    /// Types something different from the U.S. layout without Option.
    var changed = false
    var isOption = false
}

/// Draws a layout on a Mac keyboard, the way the Windows setup program draws it on a PC keyboard
/// (installer/KeyboardView.cs): the key alone bottom left, Shift top left, Option bottom right,
/// Option+Shift top right. Option shows only what the layout itself puts there; the Mac's own Option
/// characters on the other keys are left out, as on Windows.
enum KeyboardPicture {
    enum Colors {
        static let caseColor = rgb(0x26343C)
        static let key = rgb(0xFAFCFD)
        static let changed = rgb(0xD6EEF5)
        static let modifier = rgb(0xC9D4DA)
        static let shadow = rgb(0x8EA1AB)
        static let text = rgb(0x14232B)
        static let muted = rgb(0x5B6E79)
        static let optionText = rgb(0x556B77)
        static let accent = rgb(0x0A7C99)

        static func rgb(_ hex: Int) -> NSColor {
            NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
    }

    static let uzbekLetters: Set<String> = ["ö", "Ö", "ş", "Ş", "ğ", "Ğ", "ç", "Ç", "ʼ", "ʻ"]
    static let unit: CGFloat = 64
    static let margin: CGFloat = 28
    static let pixelSize = (width: Int(15 * unit + 2 * margin), height: Int(5 * unit + 2 * margin))

    // A MacBook's ANSI keyboard, 15 key widths per row, by Mac key code.
    static func rows(for klc: KlcLayout, us: Keylayout) -> [[KeyCap]] {
        func key(_ code: Int) -> KeyCap {
            let k = klc.keys[code]
            let chars = [k?.base, k?.shift, k?.altGr, k?.altGrShift]
            let changed = chars[0] != us.plain(map: 0, code: code).output || chars[1] != us.plain(map: 1, code: code).output
            return KeyCap(code: code, width: 1, chars: chars, changed: changed)
        }
        func named(_ label: String, _ width: Double, isOption: Bool = false) -> KeyCap {
            KeyCap(label: label, width: width, isOption: isOption)
        }
        return [
            [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24].map(key) + [named("delete", 2)],
            [named("tab", 1.5)] + [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30].map(key) + [{ var k = key(42); k.width = 1.5; return k }()],
            [named("caps lock", 1.75)] + [0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39].map(key) + [named("return", 2.25)],
            [named("shift", 2.25)] + [6, 7, 8, 9, 11, 45, 46, 43, 47, 44].map(key) + [named("shift", 2.75)],
            [named("fn", 1), named("control", 1), named("option", 1, isOption: true), named("command", 1.25),
             named("", 5.5), named("command", 1.25), named("option", 1, isOption: true),
             named("←", 1), named("↑↓", 1), named("→", 1)],
        ]
    }

    /// Where each key's cell sits, in pixels from the top left.
    static func cells(_ rows: [[KeyCap]]) -> [(cap: KeyCap, cell: CGRect)] {
        let gap = unit * 0.08
        var cells: [(KeyCap, CGRect)] = []
        for (row, keys) in rows.enumerated() {
            var x = margin
            for cap in keys {
                let width = CGFloat(cap.width) * unit
                cells.append((cap, CGRect(x: x + gap / 2, y: margin + CGFloat(row) * unit + gap / 2, width: width - gap, height: unit - gap)))
                x += width
            }
        }
        return cells
    }

    static func face(of cell: CGRect) -> CGRect {
        CGRect(x: cell.minX, y: cell.minY, width: cell.width, height: cell.height - unit * 0.06)
    }

    /// The top face of a character key, in pixels from the top left.
    static func faceRect(code: Int, in rows: [[KeyCap]]) -> CGRect? {
        cells(rows).first { $0.cap.code == code }.map { face(of: $0.cell) }
    }

    /// The picture as PNG, `scale` times `pixelSize`, so it stays sharp in a large window.
    static func png(for klc: KlcLayout, us: Keylayout, scale: Int = 1) throws -> Data {
        let size = (width: pixelSize.width * scale, height: pixelSize.height * scale)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size.width, pixelsHigh: size.height,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw SystemLayoutError(description: "Could not draw the keyboard picture.")
        }
        // Draw from the top left, like the Windows picture.
        context.cgContext.translateBy(x: 0, y: CGFloat(size.height))
        context.cgContext.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)

        let rim = unit * 0.22
        Colors.caseColor.setFill()
        NSBezierPath(roundedRect: CGRect(x: margin - rim, y: margin - rim, width: 15 * unit + 2 * rim, height: 5 * unit + 2 * rim),
                     xRadius: unit * 0.25, yRadius: unit * 0.25).fill()
        for (cap, cell) in cells(rows(for: klc, us: us)) {
            if cap.label == "↑↓" {
                // The up and down arrows share one key width, each half as tall.
                let half = (cell.height - unit * 0.04) / 2
                drawKey(KeyCap(label: "↑", width: 1), cell: CGRect(x: cell.minX, y: cell.minY, width: cell.width, height: half))
                drawKey(KeyCap(label: "↓", width: 1), cell: CGRect(x: cell.minX, y: cell.maxY - half, width: cell.width, height: half))
            } else {
                drawKey(cap, cell: cell)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw SystemLayoutError(description: "Could not save the keyboard picture.")
        }
        return data
    }

    static func drawKey(_ cap: KeyCap, cell: CGRect) {
        let radius = unit * 0.12
        let face = face(of: cell)
        Colors.shadow.setFill()
        NSBezierPath(roundedRect: CGRect(x: cell.minX, y: cell.minY + unit * 0.06, width: cell.width, height: face.height),
                     xRadius: radius, yRadius: radius).fill()
        let facePath = NSBezierPath(roundedRect: face, xRadius: radius, yRadius: radius)
        (cap.label != nil ? Colors.modifier : cap.changed ? Colors.changed : Colors.key).setFill()
        facePath.fill()
        if cap.isOption {
            Colors.accent.setStroke()
            facePath.lineWidth = max(1.5, unit * 0.045)
            facePath.stroke()
        }

        let inner = face.insetBy(dx: unit * 0.12, dy: unit * 0.09)
        if let label = cap.label {
            let arrow = ["←", "→", "↑", "↓"].contains(label)
            draw(label, size: arrow ? 0.24 : cap.isOption ? 0.19 : 0.17, bold: cap.isOption,
                 color: cap.isOption ? Colors.accent : Colors.muted, in: inner, right: false, bottom: true)
            return
        }
        // Left half: the key alone and with Shift. A letter pair prints once, as the capital.
        if isCasePair(cap.chars[0], cap.chars[1]) {
            draw(cap.chars[1], size: 0.34, in: inner, right: false, bottom: false)
        } else {
            draw(cap.chars[1], size: 0.25, in: inner, right: false, bottom: false)
            draw(cap.chars[0], size: 0.25, in: inner, right: false, bottom: true)
        }
        // Right half: Option and Option+Shift.
        if isCasePair(cap.chars[2], cap.chars[3]) {
            draw(cap.chars[3], size: 0.25, color: Colors.optionText, in: inner, right: true, bottom: true)
        } else {
            draw(cap.chars[3], size: 0.21, color: Colors.optionText, in: inner, right: true, bottom: false)
            draw(cap.chars[2], size: 0.21, color: Colors.optionText, in: inner, right: true, bottom: true)
        }
    }

    static func isCasePair(_ lower: String?, _ upper: String?) -> Bool {
        guard let lower, let upper, lower.count == 1, lower != upper, lower.first!.isLetter else { return false }
        return upper == lower.uppercased()
    }

    /// Draws text in a corner of `area`. Uzbek letters are bold, larger and in the accent color.
    static func draw(_ text: String?, size: CGFloat, bold: Bool = false, color: NSColor = Colors.text,
                     in area: CGRect, right: Bool, bottom: Bool) {
        guard let text, !text.isEmpty else { return }
        let uzbek = uzbekLetters.contains(text)
        // Large enough that the thin ʼ and ʻ marks stay readable.
        let points = uzbek ? max(size + 0.02, text == "ʼ" || text == "ʻ" ? 0.32 : 0) : size
        let string = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: unit * points, weight: uzbek || bold ? .bold : .regular),
            .foregroundColor: uzbek ? Colors.accent : color,
        ])
        let textSize = string.size()
        string.draw(at: CGPoint(x: right ? area.maxX - textSize.width : area.minX,
                                y: bottom ? area.maxY - textSize.height : area.minY))
    }
}
