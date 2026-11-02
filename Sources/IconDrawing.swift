import AppKit

enum KhordIcon {
    static func menu(active: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 21, height: 18), flipped: false) { _ in
            drawMark(color: active ? .systemGreen : .black)
            return true
        }
        image.isTemplate = !active
        image.accessibilityDescription = "Khord"
        return image
    }
    static func drawMark(color: NSColor) {
        color.setStroke()
        let bridge = NSBezierPath()
        bridge.move(to: NSPoint(x: 9, y: 10))
        bridge.line(to: NSPoint(x: 12, y: 8))
        bridge.lineWidth = 2.2
        bridge.lineCapStyle = .butt
        bridge.stroke()
        for rect in [NSRect(x: 1.5, y: 7, width: 8, height: 9), NSRect(x: 11.5, y: 2, width: 8, height: 9)] {
            let key = NSBezierPath(roundedRect: rect, xRadius: 2.3, yRadius: 2.3)
            key.lineWidth = 1.8
            key.stroke()
        }
    }
    static func drawApp() {
        let tile = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 208, yRadius: 208)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = 22
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.22, alpha: 1).setFill()
        tile.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: NSColor(calibratedRed: 0.27, green: 0.22, blue: 0.46, alpha: 1),
                   ending: NSColor(calibratedRed: 0.10, green: 0.08, blue: 0.18, alpha: 1))!.draw(in: tile, angle: -75)
        NSColor.white.withAlphaComponent(0.10).setStroke()
        tile.lineWidth = 2
        tile.stroke()
        let ivory = NSColor(calibratedRed: 0.96, green: 0.95, blue: 1, alpha: 1)
        let mint = NSColor(calibratedRed: 0.62, green: 0.98, blue: 0.77, alpha: 1)
        // A bridge joins two keycaps; the same silhouette is used in the menu bar.
        let bridge = NSBezierPath()
        bridge.move(to: NSPoint(x: 490, y: 523))
        bridge.line(to: NSPoint(x: 534, y: 499))
        bridge.lineWidth = 66
        bridge.lineCapStyle = .butt
        mint.setStroke()
        bridge.stroke()
        for (rect, color) in [(NSRect(x: 210, y: 479, width: 269, height: 300), ivory),
                              (NSRect(x: 545, y: 245, width: 269, height: 300), mint)] {
            let key = NSBezierPath(roundedRect: rect, xRadius: 75, yRadius: 75)
            key.lineWidth = 49
            color.setStroke()
            key.stroke()
        }
    }
}
