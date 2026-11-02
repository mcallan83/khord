import AppKit

@main struct GenerateIcons {
    static func png(size: Int, draw: () -> Void) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let transform = AffineTransform(scale: CGFloat(size) / 1024)
        (transform as NSAffineTransform).concat()
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("Usage: generate-icons OUTPUT_DIRECTORY\n".utf8))
            exit(64)
        }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        var cache: [Int: Data] = [:]
        func appPNG(_ size: Int) -> Data {
            if let data = cache[size] { return data }
            let data = png(size: size) { KhordIcon.drawApp() }
            cache[size] = data
            return data
        }
        let iconset = root.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let data = appPNG(points * scale)
                let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
                try data.write(to: iconset.appendingPathComponent(name))
            }
        }
        try appPNG(1024).write(to: root.appendingPathComponent("Khord-AppIcon.png"))
        // Standard ICNS PNG representations, written directly to avoid conversion services.
        func word(_ value: UInt32) -> Data {
            var big = value.bigEndian
            return withUnsafeBytes(of: &big) { Data($0) }
        }
        var chunks = Data()
        for (type, size) in [("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024), ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)] {
            let data = appPNG(size)
            chunks.append(Data(type.utf8)); chunks.append(word(UInt32(data.count + 8))); chunks.append(data)
        }
        var icns = Data("icns".utf8)
        icns.append(word(UInt32(chunks.count + 8))); icns.append(chunks)
        try icns.write(to: root.appendingPathComponent("Khord.icns"))

        for scale in [1, 2] {
            let size = NSSize(width: 21 * scale, height: 18 * scale)
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            (AffineTransform(scale: CGFloat(scale)) as NSAffineTransform).concat()
            KhordIcon.drawMark(color: .black)
            NSGraphicsContext.restoreGraphicsState()
            try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("MenuBar\(scale == 2 ? "@2x" : "").png"))
        }

        let preview = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 680,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: preview)
        NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 1200, height: 680).fill()
        NSImage(contentsOf: root.appendingPathComponent("Khord-AppIcon.png"))!.draw(in: NSRect(x: 60, y: 115, width: 460, height: 460))
        func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat = 20, bold: Bool = false) {
            (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
                .font: NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular),
                .foregroundColor: NSColor(calibratedWhite: 0.15, alpha: 1)])
        }
        label("Khord", x: 77, y: 575, size: 36, bold: true)
        label("App icon", x: 77, y: 78)
        label("Menu bar", x: 655, y: 575, size: 28, bold: true)
        NSColor(calibratedWhite: 0.89, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 625, y: 385, width: 510, height: 85), xRadius: 18, yRadius: 18).fill()
        KhordIcon.menu().draw(in: NSRect(x: 670, y: 420, width: 21, height: 18))
        KhordIcon.menu(active: true).draw(in: NSRect(x: 950, y: 420, width: 21, height: 18))
        label("Idle", x: 670, y: 335)
        label("S+D active", x: 950, y: 335)
        KhordIcon.menu().draw(in: NSRect(x: 660, y: 190, width: 84, height: 72))
        KhordIcon.menu(active: true).draw(in: NSRect(x: 940, y: 190, width: 84, height: 72))
        label("Actual size above · enlarged below", x: 655, y: 95, size: 17)
        NSGraphicsContext.restoreGraphicsState()
        try preview.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Khord-Icons-Preview.png"))
    }
}
