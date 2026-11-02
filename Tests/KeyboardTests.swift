import Foundation

enum KeyboardTests {
    static func typing(_ t: TestSuite) {
        var c = Chord()
        t.equal(c.handle(down(1)), [.buffer])
        t.equal(c.handle(up(1)), [.replay, .pass])
        t.equal(c.handle(down(2)), [.buffer]); c.expire()
        t.equal(c.handle(down(1)), [.pass])
        c = Chord()
        t.equal(c.handle(down(1)), [.buffer])
        t.equal(c.handle(down(4)), [.replay, .pass])
        c = Chord()
        t.equal(c.handle(down(1, modified: true)), [.pass])
        t.equal(c.handle(down(2, modified: true)), [.pass])
        c = Chord()
        t.equal(c.handle(down(1)), [.buffer])
        t.equal(c.handle(down(1, repeatKey: true)), [.replay, .pass])
        for key: UInt16 in [0, 3, 49, 4, 34, 32, 43, 47] {
            c = Chord()
            t.equal(c.handle(down(key)), [.pass]); t.activate(&c)
            t.equal(c.handle(down(key, repeatKey: true)), [.pass])
            t.equal(c.handle(up(key)), [.pass])
        }
        // The OS timer can be delayed: timestamp-based recognition must still reject a late chord.
        for interval in [0.0, 59.0, 60.0, 60.001, 100.0] {
            c = Chord()
            t.equal(c.handle(down(1, ms: 100)), [.buffer])
            t.equal(c.handle(down(2, ms: 100 + interval)), interval <= 60 ? [.discardBuffer, .suppress] : [.replay, .pass])
            t.equal(c.active, interval <= 60)
        }
        c = Chord()
        t.equal(c.handle(down(1, ms: 100)), [.buffer])
        t.equal(c.handle(down(2, ms: 90)), [.replay, .pass])
        // Regression: an old window key's repeat must replay, not silently discard, a new S.
        c = Chord(); t.activate(&c)
        t.equal(c.handle(down(123)), [.window(.left)])
        _ = c.handle(up(1)); _ = c.handle(up(2))
        t.equal(c.handle(down(1)), [.buffer])
        t.equal(c.handle(down(123, repeatKey: true)), [.replay, .suppress])
        t.equal(c.pending, nil)
        t.equal(c.handle(down(2)), [.pass])
        // Same regression for an old virtual modifier's release and a mapped arrow's release.
        c = Chord(); t.activate(&c)
        _ = c.handle(down(0)); _ = c.handle(up(1)); _ = c.handle(up(2))
        t.equal(c.handle(down(1)), [.buffer])
        t.equal(c.handle(up(0)), [.replay, .suppress])
        c = Chord(); t.activate(&c)
        _ = c.handle(down(4)); _ = c.handle(up(1)); _ = c.handle(up(2))
        t.equal(c.handle(down(1)), [.buffer])
        t.equal(c.handle(up(4)), [.replay] + emit(123))
    }
    static func navigation(_ t: TestSuite) {
        for (first, second): (UInt16, UInt16) in [(1, 2), (2, 1)] {
            for (key, arrow): (UInt16, UInt16) in [(4, 123), (38, 125), (40, 126), (37, 124)] {
                var c = Chord()
                t.equal(c.handle(down(first)), [.buffer])
                t.equal(c.handle(down(second)), [.discardBuffer, .suppress])
                t.equal(c.handle(down(key)), emit(arrow))
                t.equal(c.handle(down(key, repeatKey: true)), emit(arrow))
                t.equal(c.handle(up(first)), [.suppress])
                t.equal(c.handle(up(key)), emit(arrow))
                t.equal(c.handle(up(second)), [.suppress])
                t.equal(c.handle(down(key)), [.pass])
            }
        }
    }
    static func modifiers(_ t: TestSuite) {
        let modifierKeys: [(UInt16, LayerModifiers)] = [(0, .option), (3, .command), (49, .shift)]
        for raw in 0..<8 {
            for (key, arrow): (UInt16, UInt16) in [(4, 123), (38, 125), (40, 126), (37, 124)] {
                var c = Chord(); t.activate(&c)
                var mods: LayerModifiers = []
                for (modifierKey, modifier) in modifierKeys where LayerModifiers(rawValue: raw).contains(modifier) {
                    mods.insert(modifier)
                    t.equal(c.handle(down(modifierKey)), [.modifiers(mods), .suppress])
                    t.equal(c.handle(down(modifierKey, repeatKey: true)), [.suppress])
                }
                let page = mods.contains(.option) && (key == 38 || key == 40)
                let code = page ? (key == 38 ? UInt16(121) : UInt16(116)) : arrow
                let outputMods = page ? mods.subtracting(.option) : mods
                t.equal(c.handle(down(key)), emit(code, outputMods))
                t.equal(c.handle(down(key, repeatKey: true)), emit(code, outputMods))
                t.equal(c.handle(up(key)), emit(code, outputMods))
                for (modifierKey, modifier) in modifierKeys where mods.contains(modifier) {
                    mods.remove(modifier)
                    t.equal(c.handle(up(modifierKey)), [.modifiers(mods), .suppress])
                }
            }
        }
        var c = Chord(); t.activate(&c)
        t.equal(c.handle(down(0)), [.modifiers(.option), .suppress])
        t.equal(c.handle(down(49)), [.modifiers([.option, .shift]), .suppress])
        t.equal(c.handle(up(2)), [.modifiers([]), .suppress])
        t.equal(c.handle(down(0, repeatKey: true)), [.suppress])
        t.equal(c.handle(up(0)), [.suppress]); t.equal(c.handle(up(49)), [.suppress])
        for key: UInt16 in [8, 11, 45, 15] { // F+C/B/N/R retain native Command shortcuts.
            c = Chord(); t.activate(&c)
            t.equal(c.handle(down(3)), [.modifiers(.command), .suppress])
            t.equal(c.handle(down(key)), emit(key, .command))
            t.equal(c.handle(up(3)), [.modifiers([]), .suppress])
            t.equal(c.handle(down(key, repeatKey: true)), emit(key))
            t.equal(c.handle(up(key)), emit(key))
            t.equal(c.handle(down(key, modified: true)), [.pass])
        }
    }
    static func shortcuts(_ t: TestSuite) {
        let outputs: [(UInt16, KeyOutput)] = [
            (34, KeyOutput(code: 123, modifiers: [.command, .option], exact: true)),
            (31, KeyOutput(code: 124, modifiers: [.command, .option], exact: true)),
            (32, KeyOutput(code: 18, modifiers: .command, exact: true)),
            (35, KeyOutput(code: 25, modifiers: .command, exact: true)),
            (11, KeyOutput(code: 33, modifiers: .command, exact: true)),
            (45, KeyOutput(code: 30, modifiers: .command, exact: true)),
            (15, KeyOutput(code: 17, modifiers: [.command, .shift], exact: true, repeatable: false)),
            (51, KeyOutput(code: 51, modifiers: .option, exact: true))]
        for (key, output) in outputs {
            var c = Chord()
            t.equal(c.handle(down(key)), [.pass]); t.equal(c.handle(up(key)), [.pass])
            t.activate(&c)
            t.equal(c.handle(down(key)), [.emit(output)])
            t.equal(c.handle(down(key, repeatKey: true)), output.repeatable ? [.emit(output)] : [.suppress])
            t.equal(c.handle(up(1)), [.suppress]); t.equal(c.handle(up(key)), [.emit(output)])
        }
        for extra: UInt16? in [nil, 0, 49] {
            var c = Chord(); t.activate(&c)
            _ = c.handle(down(3))
            if let extra { _ = c.handle(down(extra)) }
            t.equal(c.handle(down(51)), emit(51, .command, exact: true))
            t.equal(c.handle(down(51, repeatKey: true)), emit(51, .command, exact: true))
            _ = c.handle(up(3))
            _ = c.handle(up(1))
            t.equal(c.handle(up(51)), emit(51, .command, exact: true))
        }
        let windows: [(UInt16, WindowCommand)] = [(36, .fullScreen), (126, .maximize), (125, .restore), (8, .reading), (123, .left), (124, .right), (33, .previousDisplay), (30, .nextDisplay)]
        for (key, command) in windows {
            var c = Chord()
            t.equal(c.handle(down(key)), [.pass]); t.equal(c.handle(up(key)), [.pass])
            t.activate(&c)
            t.equal(c.handle(down(key)), [.window(command)])
            t.equal(c.handle(down(key, repeatKey: true)), [.suppress])
            _ = c.handle(up(1))
            t.equal(c.handle(up(key)), [.suppress])
            _ = c.handle(up(2))
            t.equal(c.handle(down(key)), [.pass])
        }
        for (key, forward): (UInt16, Bool) in [(43, false), (47, true)] {
            var c = Chord()
            t.equal(c.handle(down(key)), [.pass]); t.equal(c.handle(up(key)), [.pass])
            t.activate(&c)
            t.equal(c.handle(down(key)), [.cycleWindow(forward)])
            t.equal(c.handle(down(key, repeatKey: true)), [.suppress])
            _ = c.handle(up(1)); t.equal(c.handle(up(key)), [.suppress])
        }
    }
}
