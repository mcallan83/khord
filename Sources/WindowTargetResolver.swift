// Each provider must refer to the captured frontmost application. Never select
// an arbitrary AXWindows entry: apps can expose hidden windows and tool panels.
enum WindowTargetResolver {
    static func resolve<Window>(cancelled: () -> Bool,
                                focused: () -> Window?,
                                focusedControlWindow: () -> Window?,
                                main: () -> Window?,
                                pause: () -> Void) -> (window: Window?, source: String) {
        guard !cancelled() else { return (nil, "cancelled") }
        if let window = focused() { return (window, "focused window") }
        pause()
        guard !cancelled() else { return (nil, "cancelled") }
        if let window = focused() { return (window, "focused window (retry)") }
        guard !cancelled() else { return (nil, "cancelled") }
        if let window = focusedControlWindow() { return (window, "focused control's window") }
        guard !cancelled() else { return (nil, "cancelled") }
        if let window = main() { return (window, "main window") }
        return (nil, "no window reference")
    }
}
