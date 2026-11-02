// Physical ANSI key positions; independent of the selected input layout.
struct KeyInput {
    var code: UInt16
    var down: Bool
    var repeatKey: Bool = false
    var modified: Bool = false
    var timestamp: UInt64 = 0 // Original CGEvent timestamp; nanoseconds, monotonic.
}
struct LayerModifiers: OptionSet, Equatable {
    let rawValue: Int
    static let option = Self(rawValue: 1)
    static let command = Self(rawValue: 2)
    static let shift = Self(rawValue: 4)
}
struct KeyOutput: Equatable {
    var code: UInt16
    var modifiers: LayerModifiers = []
    // Exact shortcuts ignore physical/layer modifiers.
    var exact = false
    var repeatable = true
}
enum Decision: Equatable {
    case pass, suppress, buffer, replay, discardBuffer
    case emit(KeyOutput)
    case modifiers(LayerModifiers)
    case window(WindowCommand)
    case cycleWindow(Bool)
}
struct Chord {
    static let arrows: [UInt16: UInt16] = [4: 123, 38: 125, 40: 126, 37: 124]
    static let modifierKeys: [UInt16: LayerModifiers] = [0: .option, 3: .command, 49: .shift]
    var held = Set<UInt16>()
    var swallowed = Set<UInt16>()
    var mapped: [UInt16: KeyOutput] = [:]
    var layerHeld = Set<UInt16>()
    var pending: UInt16?
    var active: Bool { KhordDefaults.activationCodes.allSatisfy { held.contains($0) && swallowed.contains($0) } }
    var modifiers: LayerModifiers {
        guard active else { return [] }
        return layerHeld.reduce(into: LayerModifiers()) { $0.formUnion(Self.modifierKeys[$1] ?? []) }
    }
    private var pendingTimestamp: UInt64?
    mutating func expire() { pending = nil; pendingTimestamp = nil }

    mutating func handle(_ e: KeyInput) -> [Decision] {
        let wasActive = active
        let oldModifiers = modifiers
        let wasHeld = held.contains(e.code)
        if e.down { held.insert(e.code) } else { held.remove(e.code) }
        let result: [Decision]
        if let first = pending {
            let started = pendingTimestamp ?? e.timestamp
            let withinWindow = e.timestamp >= started &&
                e.timestamp - started <= UInt64(KhordDefaults.chordWindowMs * 1_000_000)
            expire()
            if e.down && !e.repeatKey && !e.modified && !wasHeld && withinWindow &&
                KhordDefaults.activationCodes.contains(e.code) && e.code != first {
                swallowed.formUnion([first, e.code])
                result = [.discardBuffer, .suppress]
            } else {
                // Flush before EVERY intervening event, including consumed repeats/releases.
                result = [.replay] + handleHeldKey(e, wasHeld: wasHeld)
            }
        } else {
            result = handleHeldKey(e, wasHeld: wasHeld)
        }
        if wasActive && !active {
            swallowed.formUnion(layerHeld)
            layerHeld.removeAll()
        }
        let newModifiers = modifiers
        return (oldModifiers != newModifiers ? [.modifiers(newModifiers)] : []) + result
    }
    private mutating func handleHeldKey(_ e: KeyInput, wasHeld: Bool) -> [Decision] {
        if var output = mapped[e.code] {
            if !output.exact {
                output.modifiers = modifiers
                if output.code == 121 || output.code == 116 { output.modifiers.remove(.option) }
            }
            if !e.down { mapped.removeValue(forKey: e.code) }
            return e.repeatKey && !output.repeatable ? [.suppress] : [.emit(output)]
        }
        if layerHeld.contains(e.code) {
            if !e.down { layerHeld.remove(e.code) }
            return [.suppress]
        }
        if swallowed.contains(e.code) {
            if !e.down { swallowed.remove(e.code) }
            return [.suppress]
        }
        return process(e, wasHeld: wasHeld)
    }
    private mutating func process(_ e: KeyInput, wasHeld: Bool) -> [Decision] {
        if active, e.down, !wasHeld {
            let action = e.code
            if action == 43 || action == 47 {
                swallowed.insert(e.code)
                return [.cycleWindow(action == 47)]
            }
            if let command = WindowCommand.keys[action], action != 8 || (modifiers.isEmpty && !e.modified) {
                swallowed.insert(e.code) // One action per press; consume repeats and release.
                return [.window(command)]
            }
            if Self.modifierKeys[action] != nil {
                layerHeld.insert(e.code)
                return [.suppress]
            }
            let mods = modifiers
            var output: KeyOutput?
            if let arrow = Self.arrows[action] {
                if mods.contains(.option) && (action == 38 || action == 40) {
                    // A+J/K means Page Down/Up, not Option+Down/Up.
                    output = KeyOutput(code: action == 38 ? 121 : 116, modifiers: mods.subtracting(.option))
                } else {
                    output = KeyOutput(code: arrow, modifiers: mods)
                }
            } else {
                switch action {
                case 34: output = KeyOutput(code: 123, modifiers: [.command, .option], exact: true) // I
                case 31: output = KeyOutput(code: 124, modifiers: [.command, .option], exact: true) // O
                case 32: output = KeyOutput(code: 18, modifiers: .command, exact: true) // U -> Command+1
                case 35: output = KeyOutput(code: 25, modifiers: .command, exact: true) // P -> Command+9
                case 51: output = KeyOutput(code: 51, modifiers: mods.contains(.command) ? .command : .option, exact: true) // F+Backspace -> line start; otherwise previous word
                default: break
                }
                if output == nil && mods.isEmpty && !e.modified {
                    switch action {
                    case 11: output = KeyOutput(code: 33, modifiers: .command, exact: true) // B -> back
                    case 45: output = KeyOutput(code: 30, modifiers: .command, exact: true) // N -> forward
                    case 15: output = KeyOutput(code: 17, modifiers: [.command, .shift], exact: true, repeatable: false) // R
                    default: break
                    }
                }
                if output == nil && !mods.isEmpty && e.code != KeyboardInput.functionKey { output = KeyOutput(code: e.code, modifiers: mods) }
            }
            if let output {
                mapped[e.code] = output
                return [.emit(output)]
            }
        }
        if e.down && !wasHeld && !e.repeatKey && !e.modified && !active &&
            KhordDefaults.activationCodes.contains(e.code) && !KhordDefaults.activationCodes.contains(where: { $0 != e.code && held.contains($0) }) {
            pending = e.code
            pendingTimestamp = e.timestamp
            return [.buffer]
        }
        return [.pass]
    }
}
