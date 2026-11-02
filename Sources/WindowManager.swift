import AppKit
import ApplicationServices

// All cross-process AX calls run off the keyboard event tap's thread.
final class WindowManager {
    private let queue = DispatchQueue(label: "local.khord.windows")
    private let cancellation = Cancellation()
    private struct Record {
        let window: AXUIElement
        var original: CGRect?
        var lastApplied: CGRect?
        var directPlacement = false // Learned per window, for this session only.
    }
    private var records: [Record] = [] // Session-only; bounded to 64 windows.
    var report: ((String) -> Void)?

    func cancel() { cancellation.cancel() }
    private func token() -> Int { cancellation.current }
    private func notify(_ text: String, ticket: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.token() == ticket else { return }
            self.report?(text)
        }
    }
    func perform(_ command: WindowCommand) {
        // Called asynchronously on main, after the key callback returns.
        let displays = NSScreen.screens
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let primary = displays.first else { return }
        let pid = frontmost.processIdentifier
        let primaryTop = primary.frame.maxY
        func quartz(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height)
        }
        let screens = displays.map { quartz($0.frame) }
        let areas = displays.map { quartz($0.visibleFrame) }
        let ticket = token()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let appName = frontmost.localizedName ?? "App"
        report?("\(appName) · \(command.rawValue): waiting for window lookup")
        queue.async { [weak self] in
            guard let self, self.token() == ticket else { return }
            let app = AXAccess.application(pid, timeout: 0.25)
            var lookupErrors: [String] = []
            func reference(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
                let result = AXAccess.readResult(element, attribute)
                lookupErrors.append("\(attribute): \(AXAccess.errorDescription(result.error))")
                return AXAccess.element(result.value)
            }
            let resolved = WindowTargetResolver.resolve(
                cancelled: { self.token() != ticket },
                focused: { reference(app, kAXFocusedWindowAttribute) },
                focusedControlWindow: {
                    guard let control = reference(app, kAXFocusedUIElementAttribute) else { return nil }
                    return reference(control, kAXWindowAttribute)
                },
                main: { reference(app, kAXMainWindowAttribute) },
                pause: { Thread.sleep(forTimeInterval: 0.05) })
            guard self.token() == ticket else { return }
            func report(_ message: String) {
                self.notify("\(appName) · \(command.rawValue) · \(resolved.source): \(message)", ticket: ticket)
            }
            guard let window = resolved.window else {
                report("No focused window available (\(lookupErrors.joined(separator: ", ")))"); return
            }
            AXUIElementSetMessagingTimeout(window, 0.25)
            guard let frame = AXAccess.frame(window) else {
                report("App does not expose its window frame"); return
            }
            let index: Int
            if let existing = self.records.firstIndex(where: { CFEqual($0.window, window) }) {
                index = existing
            } else {
                if self.records.count >= 64 { self.records.removeFirst() }
                index = self.records.count
                self.records.append(Record(window: window))
            }
            let full = self.fullScreen(window)
            if !full {
                if self.records[index].original == nil || (self.records[index].lastApplied.map { !WindowLayout.close(frame, $0) } ?? true) {
                    self.records[index].original = frame
                }
            }
            guard self.token() == ticket else { return }
            if command == .fullScreen && !full {
                let result = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanTrue)
                report(result == .success ? "Full screen requested" : "App refused full screen (AX \(result.rawValue))")
                return
            }
            if full {
                guard AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse) == .success else {
                    report("App refused to leave full screen"); return
                }
                // Full-screen Spaces animate asynchronously. Wait for non-full-screen and a stable frame.
                let deadline = ProcessInfo.processInfo.systemUptime + 6
                var stable = 0
                var previous: CGRect?
                while ProcessInfo.processInfo.systemUptime < deadline && self.token() == ticket {
                    Thread.sleep(forTimeInterval: 0.15)
                    if !self.fullScreen(window), let current = AXAccess.frame(window) {
                        stable = previous.map { WindowLayout.close(current, $0, tolerance: 1) } == true ? stable + 1 : 0
                        previous = current
                        if stable >= 4 { break }
                    } else { stable = 0; previous = nil }
                }
                guard self.token() == ticket else { return }
                guard !self.fullScreen(window), stable >= 4 else {
                    report("Full-screen exit did not finish — try again"); return
                }
            }
            guard self.token() == ticket else { return }
            guard let current = AXAccess.frame(window) else {
                report("Window frame became unavailable after selection"); return
            }
            guard let screen = WindowLayout.screenIndex(for: current, screens: screens) else {
                report("Could not locate the window's display"); return
            }
            if self.records[index].original == nil { self.records[index].original = current }
            if command == .fullScreen {
                report("Left full screen")
                return
            }
            let target: CGRect
            switch command {
            case .fullScreen: return
            case .maximize, .reading, .left, .right:
                target = WindowLayout.tile(command, current: current, area: areas[screen])
            case .restore:
                target = WindowLayout.restoredFrame(self.records[index].original ?? current, displays: screens, fallbackArea: areas[screen])
            case .previousDisplay, .nextDisplay:
                guard let neighbor = WindowLayout.neighbor(from: screen, screens: screens, right: command == .nextDisplay) else {
                    report("No display to the \(command == .nextDisplay ? "right" : "left")"); return
                }
                target = WindowLayout.transfer(current, from: areas[screen], to: areas[neighbor])
            }
            guard self.token() == ticket else { return }
            var error = self.animateFrame(window, from: current, to: target, ticket: ticket, reduceMotion: reduceMotion || self.records[index].directPlacement, duration: KhordDefaults.animationDurationMs / 1000)
            let immediatelyApplied = AXAccess.frame(window).map { WindowLayout.close($0, target, tolerance: 2) } ?? false
            if error != .success || !immediatelyApplied {
                self.records[index].directPlacement = true
                // Recover delayed or transiently refused updates in any app. Retry
                // the SAME window and target; never advance the tiling cycle.
                error = WindowFrameSettlement.finish(target: target, initialError: error,
                    cancelled: { self.token() != ticket },
                    read: { AXAccess.frame(window) },
                    write: { AXAccess.setFrame(window, target) },
                    pause: { Thread.sleep(forTimeInterval: 0.05) })
            }
            guard self.token() == ticket else { return }
            if let actual = AXAccess.frame(window) {
                self.records[index].lastApplied = actual
                report(error == .success && WindowLayout.close(actual, target) ? "Window updated" : "App limited/refused layout (AX \(error.rawValue)); requested \(target), actual \(actual)")
            } else {
                report("Window update failed (AX \(error.rawValue))")
            }
        }
    }
    private func fullScreen(_ window: AXUIElement) -> Bool {
        (AXAccess.read(window, "AXFullScreen") as? Bool) ?? false
    }
    private func animateFrame(_ window: AXUIElement, from start: CGRect, to target: CGRect,
                              ticket: Int, reduceMotion: Bool, duration: Double) -> AXError {
        // Deadline-based rather than a fixed count: slow AX clients skip intermediate frames.
        let began = ProcessInfo.processInfo.systemUptime
        if duration > 0 && !reduceMotion && !WindowLayout.close(start, target, tolerance: 1) {
            while token() == ticket {
                let remaining = began + duration - ProcessInfo.processInfo.systemUptime
                if remaining <= 0 { break }
                Thread.sleep(forTimeInterval: min(1.0 / 60.0, remaining))
                guard token() == ticket else { return .failure }
                let progress = (ProcessInfo.processInfo.systemUptime - began) / duration
                if progress >= 1 { break }
                let frame = WindowLayout.interpolated(from: start, to: target, progress: progress)
                if AXAccess.setFrame(window, frame, finalize: false) != .success { break }
            }
        }
        guard token() == ticket else { return .failure }
        return AXAccess.setFrame(window, target) // Always finish at the exact requested frame.
    }
}
