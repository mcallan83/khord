import CoreGraphics

enum LayoutTests {
    static func geometry(_ t: TestSuite) {
        let area = CGRect(x: -1200, y: 25, width: 1000, height: 800)
        let original = CGRect(x: -1000, y: 100, width: 600, height: 400)
        var current = original
        for width: CGFloat in [500, 300, 700, 500] {
            current = WindowLayout.tile(.left, current: current, area: area)
            t.rect(current, CGRect(x: -1200, y: 25, width: width, height: 800))
        }
        current = original
        for width: CGFloat in [500, 700, 300, 500] {
            current = WindowLayout.tile(.right, current: current, area: area)
            t.rect(current, CGRect(x: area.maxX - width, y: 25, width: width, height: 800))
        }
        t.rect(WindowLayout.tile(.maximize, current: original, area: area), area)
        t.rect(WindowLayout.tile(.reading, current: original, area: area), CGRect(x: -1200, y: 65, width: 1000, height: 720))
        t.rect(WindowLayout.tile(.reading, current: original, area: CGRect(x: 0, y: 0, width: 2000, height: 1200)), CGRect(x: 450, y: 60, width: 1100, height: 1080))
        let screens = [area, CGRect(x: 0, y: 0, width: 2000, height: 1200), CGRect(x: 2000, y: -500, width: 1000, height: 800)]
        t.equal(WindowLayout.screenIndex(for: original, screens: screens), 0)
        t.equal(WindowLayout.screenIndex(for: original, screens: []), nil)
        t.equal(WindowLayout.neighbor(from: 0, screens: screens, right: false), nil)
        t.equal(WindowLayout.neighbor(from: 0, screens: screens, right: true), 1)
        t.equal(WindowLayout.neighbor(from: 2, screens: screens, right: false), 1)
        t.equal(WindowLayout.neighbor(from: 2, screens: screens, right: true), nil)
        let left = CGRect(x: -1200, y: 25, width: 500, height: 800)
        let right = CGRect(x: -700, y: 25, width: 500, height: 800)
        t.rect(WindowLayout.transfer(left, from: area, to: screens[1]), CGRect(x: 0, y: 0, width: 1000, height: 1200))
        t.rect(WindowLayout.transfer(right, from: area, to: screens[1]), CGRect(x: 1000, y: 0, width: 1000, height: 1200))
        t.rect(WindowLayout.transfer(area, from: area, to: screens[1]), screens[1])
        t.rect(WindowLayout.restoredFrame(original, displays: screens, fallbackArea: screens[1]), original)
        t.rect(WindowLayout.restoredFrame(original, displays: [screens[1]], fallbackArea: screens[1]), CGRect(x: 700, y: 400, width: 600, height: 400))
        let spanning = CGRect(x: -100, y: 0, width: 500, height: 500)
        t.rect(WindowLayout.restoredFrame(spanning, displays: [screens[1]], fallbackArea: screens[1]), spanning)
        let moved = WindowLayout.transfer(CGRect(x: -1400, y: -100, width: 2000, height: 1600), from: area, to: screens[1])
        t.rect(moved, screens[1]) // Oversized/offscreen windows are clamped to the target.
        t.rect(WindowLayout.interpolated(from: original, to: area, progress: -1), original)
        t.rect(WindowLayout.interpolated(from: original, to: area, progress: 2), area)
        var previousWidth = original.width
        for step in 0...10 {
            let frame = WindowLayout.interpolated(from: original, to: area, progress: Double(step) / 10)
            t.check(frame.minX >= area.minX && frame.minX <= original.minX, "Animation must not overshoot")
            t.check(frame.width >= previousWidth && frame.width <= area.width, "Animation must be monotonic")
            previousWidth = frame.width
        }
    }
    static func cycling(_ t: TestSuite) {
        let positions = [
            CycleWindowPosition(id: 4, frame: CGRect(x: 500, y: 0, width: 600, height: 400)),
            CycleWindowPosition(id: 3, frame: CGRect(x: 0, y: 0, width: 600, height: 400)),
            CycleWindowPosition(id: 5, frame: CGRect(x: -1200, y: 0, width: 600, height: 400)),
            CycleWindowPosition(id: 2, frame: CGRect(x: 0, y: 300, width: 600, height: 400)),
            CycleWindowPosition(id: 1, frame: CGRect(x: 0, y: 0, width: 600, height: 400)),
            CycleWindowPosition(id: 6, frame: CGRect(x: 1600, y: 0, width: 600, height: 400))]
        let expected: [UInt32] = [5, 1, 3, 2, 4, 6]
        t.equal(WindowCycleOrder(windows: positions, current: 1).ids, expected)
        t.equal(WindowCycleOrder(windows: positions.reversed(), current: 1).ids, expected)
        for forward in [true, false] {
            var cycle = WindowCycleOrder(windows: positions, current: 1)
            var visited = Set<UInt32>()
            for _ in positions { if let id = cycle.next(forward: forward) { visited.insert(id) } }
            t.equal(visited, Set(expected))
            t.equal(cycle.current, 1)
            t.equal(cycle.next(forward: forward), forward ? 3 : 5)
            t.equal(cycle.next(forward: !forward), 1)
            t.equal(cycle.position, 2)
        }
        var cycle = WindowCycleOrder(windows: positions, current: 6)
        t.equal(cycle.next(forward: true), 5)
        cycle = WindowCycleOrder(windows: positions, current: 5)
        t.equal(cycle.next(forward: false), 6)
        cycle = WindowCycleOrder(windows: positions, current: 999)
        t.equal(cycle.next(forward: true), 5)
        cycle = WindowCycleOrder(windows: positions, current: nil)
        t.equal(cycle.next(forward: false), 6)
        cycle = WindowCycleOrder(windows: [], current: nil)
        t.equal(cycle.next(forward: true), nil)
        cycle = WindowCycleOrder(windows: [positions[0]], current: 4)
        t.equal(cycle.next(forward: true), 4); t.equal(cycle.next(forward: false), 4)
        // Windows across left/right and vertically arranged monitors share one cycle.
        let acrossDisplays = positions + [CycleWindowPosition(id: 7,
            frame: CGRect(x: 0, y: -900, width: 600, height: 400))]
        var global = WindowCycleOrder(windows: acrossDisplays, current: 5)
        let globalExpected: [UInt32] = [7, 1, 3, 2, 4, 6, 5]
        t.equal(globalExpected.map { _ in global.next(forward: true)! }, globalExpected)
        t.equal(global.next(forward: false), 6)
    }
}
