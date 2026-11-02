import CoreGraphics

// Decode only ordinary key events. Physical modifiers, including Fn/Globe,
// pass through as flagsChanged in the event tap.
enum KeyboardInput {
    static let functionKey: UInt16 = 63
    static func decode(type: CGEventType, code: UInt16, flags: CGEventFlags,
                       repeating: Bool = false,
                       timestamp: UInt64 = 0) -> KeyInput? {
        guard type == .keyDown || type == .keyUp else { return nil }
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        return KeyInput(code: code, down: type == .keyDown, repeatKey: type == .keyDown && repeating,
                        modified: !flags.intersection(modifiers).isEmpty, timestamp: timestamp)
    }
}

// Starting the tap must not depend on global session key state: it can retain
// synthetic/stale key-downs. Let existing holds finish without interpreting
// repeats as a new chord. A fresh non-repeat press also clears a stale snapshot.
struct StartupKeyGate {
    private(set) var remaining: Set<UInt16>
    init(heldAtStartup: Set<UInt16> = []) { remaining = heldAtStartup }
    mutating func accepts(_ input: KeyInput) -> Bool {
        guard remaining.contains(input.code) else { return true }
        if !input.down { remaining.remove(input.code); return false }
        if input.repeatKey { return false }
        remaining.remove(input.code)
        return true
    }
}
