import Foundation
import CoreGraphics

enum WindowCommand: String, Equatable {
    case fullScreen, maximize, restore, reading, left, right, previousDisplay, nextDisplay
    static let keys: [UInt16: Self] = [36: .fullScreen, 126: .maximize,
        125: .restore, 123: .left, 124: .right, 33: .previousDisplay, 30: .nextDisplay, 8: .reading]
}
struct WindowLayout {
    static func interpolated(from start: CGRect, to target: CGRect, progress: Double) -> CGRect {
        let t = CGFloat(min(1, max(0, progress)))
        let eased = 1 - (1 - t) * (1 - t) * (1 - t) // Quick ease-out; no overshoot.
        return CGRect(x: start.minX + (target.minX - start.minX) * eased,
                      y: start.minY + (target.minY - start.minY) * eased,
                      width: start.width + (target.width - start.width) * eased,
                      height: start.height + (target.height - start.height) * eased)
    }
    static func close(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 8) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance &&
        abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
    static func tile(_ command: WindowCommand, current: CGRect, area: CGRect) -> CGRect {
        if command == .maximize { return area }
        if command == .reading {
            let width = min(CGFloat(KhordDefaults.readingWidthPx), area.width)
            let height = area.height * 0.9
            return CGRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height)
        }
        let right = command == .right
        let widths = right ? KhordDefaults.tileRightWidths : KhordDefaults.tileLeftWidths
        let match = widths.indices.filter { index in
            let width = area.width * CGFloat(widths[index] / 100)
            let rect = CGRect(x: right ? area.maxX - width : area.minX, y: area.minY, width: width, height: area.height)
            return close(current, rect, tolerance: 2)
        }.min { abs(current.width - area.width * CGFloat(widths[$0] / 100)) < abs(current.width - area.width * CGFloat(widths[$1] / 100)) }
        let fraction = CGFloat(widths[match.map { ($0 + 1) % widths.count } ?? 0] / 100)
        let width = area.width * fraction
        return CGRect(x: right ? area.maxX - width : area.minX, y: area.minY, width: width, height: area.height)
    }
    static func screenIndex(for frame: CGRect, screens: [CGRect]) -> Int? {
        screens.indices.max { a, b in
            let ra = frame.intersection(screens[a]); let rb = frame.intersection(screens[b])
            let aa = ra.isNull ? 0 : ra.width * ra.height
            let ab = rb.isNull ? 0 : rb.width * rb.height
            if aa != ab { return aa < ab }
            return hypot(frame.midX - screens[a].midX, frame.midY - screens[a].midY) >
                hypot(frame.midX - screens[b].midX, frame.midY - screens[b].midY)
        }
    }
    static func neighbor(from index: Int, screens: [CGRect], right: Bool) -> Int? {
        screens.indices.filter { $0 != index && (right ? screens[$0].midX > screens[index].midX : screens[$0].midX < screens[index].midX) }
            .min { a, b in
                let da = abs(screens[a].midX - screens[index].midX)
                let db = abs(screens[b].midX - screens[index].midX)
                if da != db { return da < db }
                return abs(screens[a].midY - screens[index].midY) < abs(screens[b].midY - screens[index].midY)
            }
    }
    static func restoredFrame(_ original: CGRect, displays: [CGRect], fallbackArea: CGRect) -> CGRect {
        // Preserve intentional spanning/partially offscreen positions, but do not
        // strand a restored window on a monitor that has been disconnected.
        if displays.contains(where: { original.intersects($0) }) { return original }
        let width = min(original.width, fallbackArea.width)
        let height = min(original.height, fallbackArea.height)
        return CGRect(x: fallbackArea.midX - width / 2, y: fallbackArea.midY - height / 2, width: width, height: height)
    }
    static func transfer(_ frame: CGRect, from: CGRect, to: CGRect) -> CGRect {
        let width = min(to.width, frame.width * to.width / max(1, from.width))
        let height = min(to.height, frame.height * to.height / max(1, from.height))
        let x = to.minX + (frame.minX - from.minX) / max(1, from.width) * to.width
        let y = to.minY + (frame.minY - from.minY) / max(1, from.height) * to.height
        return CGRect(x: min(max(x, to.minX), to.maxX - width), y: min(max(y, to.minY), to.maxY - height), width: width, height: height)
    }
}
