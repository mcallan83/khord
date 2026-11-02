import ApplicationServices

enum WindowSettlementTests {
    static func run(_ t: TestSuite) {
        let target = CGRect(x: 0, y: 25, width: 700, height: 900)
        let old = CGRect(x: 500, y: 25, width: 700, height: 900)
        var polls = 0
        var writes = 0
        func run(cancelled: @escaping () -> Bool = { false }, frame: @escaping () -> CGRect?) -> AXError {
            WindowFrameSettlement.finish(target: target, initialError: .success,
                cancelled: cancelled, read: frame,
                write: { writes += 1; return .success }, pause: { polls += 1 })
        }
        t.equal(run(frame: { polls < 3 ? old : target }), .success)
        t.equal(polls, 4)
        t.equal(writes, 0)
        polls = 0; writes = 0
        t.equal(run(frame: { writes == 0 ? old : target }), .success)
        t.equal(writes, 1)
        t.equal(polls, 6)
        polls = 0; writes = 0
        _ = run(frame: { nil })
        t.equal(polls, 12)
        t.check(writes == 2, "Unresponsive windows must not cause unlimited retries")
        polls = 0; writes = 0
        t.equal(run(cancelled: { polls >= 1 }, frame: { old }), .failure)
        t.equal(writes, 0)
        t.equal(polls, 1)
        polls = 0
        _ = run(frame: { polls == 1 ? target : old })
        t.check(polls == 12, "One transient matching frame is insufficient")
    }
}
