import CoreGraphics

struct CycleWindowPosition {
    let id: UInt32
    let frame: CGRect
}
struct WindowCycleOrder {
    let ids: [UInt32]
    private(set) var current: UInt32?
    private var index: Int?
    var position: Int? { index.map { $0 + 1 } }
    init(windows: [CycleWindowPosition], current: UInt32?) {
        ids = windows.sorted {
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            if $0.frame.minY != $1.frame.minY { return $0.frame.minY < $1.frame.minY }
            return $0.id < $1.id // Overlapping windows remain distinct and deterministic.
        }.map { $0.id }
        self.current = current
        index = current.flatMap { ids.firstIndex(of: $0) }
    }
    mutating func next(forward: Bool) -> UInt32? {
        guard !ids.isEmpty else { return nil }
        let nextIndex = index.map { ($0 + (forward ? 1 : ids.count - 1)) % ids.count } ?? (forward ? 0 : ids.count - 1)
        index = nextIndex
        current = ids[nextIndex]
        return current
    }
}
