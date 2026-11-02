import Foundation
import ApplicationServices

enum LifecycleTests {
    static func inputAndStartup(_ t: TestSuite) {
        let input = KeyboardInput.decode(type: .keyDown, code: 4, flags: .maskShift, repeating: true, timestamp: 42)
        t.check(input?.modified == true && input?.repeatKey == true && input?.timestamp == 42)
        t.check(KeyboardInput.decode(type: .keyUp, code: 4, flags: [], repeating: true)?.repeatKey == false)
        t.check(KeyboardInput.decode(type: .keyDown, code: 122, flags: .maskSecondaryFn)?.modified == false)
        for code: UInt16 in [56, 63] {
            t.check(KeyboardInput.decode(type: .flagsChanged, code: code, flags: .maskSecondaryFn) == nil, "Modifier events must pass through the native flagsChanged path")
        }
        var gate = StartupKeyGate(heldAtStartup: [1, 4])
        t.check(!gate.accepts(down(1, repeatKey: true)))
        t.check(!gate.accepts(up(1)))
        t.check(gate.accepts(down(1)))
        t.check(gate.accepts(down(4)), "A new press clears stale hardware state")
        t.check(gate.remaining.isEmpty)
        gate = StartupKeyGate(heldAtStartup: [4])
        var c = Chord()
        for input in [down(1), down(2)] {
            t.check(gate.accepts(input))
            _ = c.handle(input)
        }
        t.check(c.active, "A phantom held H must not block startup")
        t.check(gate.accepts(down(4)))
        t.equal(c.handle(down(4)), emit(123))
        gate = StartupKeyGate(heldAtStartup: [1])
        c = Chord()
        t.check(!gate.accepts(down(1, repeatKey: true)))
        t.check(!gate.accepts(up(1)))
        t.check(gate.accepts(down(1))); t.equal(c.handle(down(1)), [.buffer])
        t.check(gate.accepts(down(2))); t.equal(c.handle(down(2)), [.discardBuffer, .suppress])
        t.check(c.active)
    }
    static func accessAndCancellation(_ t: TestSuite) {
        let cancellation = Cancellation()
        let original = cancellation.current
        DispatchQueue.concurrentPerform(iterations: 1000) { _ in cancellation.cancel() }
        t.equal(cancellation.current, original + 1000)
        var point = CGPoint(x: -50, y: 20)
        var size = CGSize(width: 640, height: 480)
        let position = AXValueCreate(.cgPoint, &point)
        let dimensions = AXValueCreate(.cgSize, &size)
        t.equal(AXAccess.decodeFrame(position: position, size: dimensions), CGRect(origin: point, size: size))
        t.equal(AXAccess.decodeFrame(position: dimensions, size: position), nil)
        t.equal(AXAccess.decodeFrame(position: "invalid" as CFString, size: dimensions), nil)
        t.equal(AXAccess.decodeFrame(position: nil, size: nil), nil)
        size.width = .nan
        t.equal(AXAccess.decodeFrame(position: position, size: AXValueCreate(.cgSize, &size)), nil)
        size = .zero
        t.equal(AXAccess.decodeFrame(position: position, size: AXValueCreate(.cgSize, &size)), nil)
    }
}
