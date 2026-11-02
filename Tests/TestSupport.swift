import Foundation
import CoreGraphics

final class TestSuite {
    private(set) var checks = 0
    private(set) var groups = 0
    private var name = ""
    func run(_ name: String, _ body: (TestSuite) -> Void) {
        self.name = name
        let before = checks
        body(self)
        groups += 1
        print("PASS \(name) (\(checks - before) checks)")
    }
    func check(_ condition: @autoclosure () -> Bool, _ message: String = "Expectation failed",
               file: StaticString = #fileID, line: UInt = #line) {
        checks += 1
        if !condition() {
            FileHandle.standardError.write(Data("FAIL \(name): \(message) [\(file):\(line)]\n".utf8))
            exit(1)
        }
    }
    func equal<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #fileID, line: UInt = #line) {
        check(actual == expected, "Got \(actual); expected \(expected)", file: file, line: line)
    }
    func rect(_ actual: CGRect, _ expected: CGRect, file: StaticString = #fileID, line: UInt = #line) {
        check(WindowLayout.close(actual, expected, tolerance: 0.001), "Got \(actual); expected \(expected)", file: file, line: line)
    }
    func activate(_ chord: inout Chord) {
        equal(chord.handle(down(1)), [.buffer])
        equal(chord.handle(down(2)), [.discardBuffer, .suppress])
        check(chord.active, "S+D should activate the layer")
    }
}
func down(_ key: UInt16, repeatKey: Bool = false, modified: Bool = false, ms: Double = 0) -> KeyInput {
    KeyInput(code: key, down: true, repeatKey: repeatKey, modified: modified, timestamp: UInt64(ms * 1_000_000))
}
func up(_ key: UInt16, ms: Double = 0) -> KeyInput { KeyInput(code: key, down: false, timestamp: UInt64(ms * 1_000_000)) }
func emit(_ key: UInt16, _ modifiers: LayerModifiers = [], exact: Bool = false) -> [Decision] {
    [.emit(KeyOutput(code: key, modifiers: modifiers, exact: exact))]
}
