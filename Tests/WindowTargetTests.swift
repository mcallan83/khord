enum WindowTargetTests {
    static func run(_ t: TestSuite) {
        var reads = 0
        var pauses = 0
        var fallbacks = 0
        func resolve(focused: @escaping () -> Int?, control: Int? = 2, main: Int? = 3,
                     cancelled: @escaping () -> Bool = { false }) -> (window: Int?, source: String) {
            WindowTargetResolver.resolve(cancelled: cancelled, focused: focused,
                focusedControlWindow: { fallbacks += 1; return control },
                main: { fallbacks += 1; return main }, pause: { pauses += 1 })
        }
        let focused = resolve(focused: { 1 })
        t.equal(focused.window, 1)
        t.equal(pauses, 0)
        t.equal(fallbacks, 0)
        let delayed = resolve(focused: { reads += 1; return reads == 2 ? 1 : nil })
        t.equal(delayed.window, 1)
        t.equal(reads, 2)
        t.equal(pauses, 1)
        t.equal(fallbacks, 0)
        let control = resolve(focused: { nil })
        t.equal(control.window, 2)
        t.equal(control.source, "focused control's window")
        t.equal(fallbacks, 1)
        let main = resolve(focused: { nil }, control: nil)
        t.equal(main.window, 3)
        t.equal(main.source, "main window")
        t.equal(resolve(focused: { nil }, control: nil, main: nil).window, nil)
        reads = 0
        t.equal(resolve(focused: { reads += 1; return nil }, cancelled: { true }).window, nil)
        t.equal(reads, 0)
        pauses = 0; fallbacks = 0
        let cancelled = resolve(focused: { nil }, cancelled: { pauses > 0 })
        t.equal(cancelled.source, "cancelled")
        t.equal(fallbacks, 0, file: #fileID, line: #line)
    }
}
