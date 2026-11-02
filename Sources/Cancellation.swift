import Foundation

// A generation invalidates queued operations without blocking the UI thread.
final class Cancellation {
    private let lock = NSLock()
    private var generation = 0
    var current: Int { lock.lock(); defer { lock.unlock() }; return generation }
    func cancel() { lock.lock(); generation &+= 1; lock.unlock() }
}
