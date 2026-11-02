@main struct Tests {
    static func main() {
        let suite = TestSuite()
        suite.run("typing, buffering and chord timing", KeyboardTests.typing)
        suite.run("navigation and release order", KeyboardTests.navigation)
        suite.run("virtual and physical modifiers", KeyboardTests.modifiers)
        suite.run("tabs, history and window shortcuts", KeyboardTests.shortcuts)
        suite.run("window geometry and animation", LayoutTests.geometry)
        suite.run("stable window cycling", LayoutTests.cycling)
        suite.run("input decoding and startup recovery", LifecycleTests.inputAndStartup)
        suite.run("AX type safety and cancellation", LifecycleTests.accessAndCancellation)
        suite.run("asynchronous window settlement", WindowSettlementTests.run)
        suite.run("window target recovery", WindowTargetTests.run)
        print("Passed \(suite.groups) test groups, \(suite.checks) checks")
    }
}
