import AppKit
import ApplicationServices

// Focus changes and AX enumeration never run in the keyboard event callback.
final class WindowCycler {
    private struct VisibleWindow {
        let id: UInt32
        let pid: pid_t
        let frame: CGRect
        let title: String?
    }
    private struct Entry {
        let visible: VisibleWindow
        let window: AXUIElement
        let app: AXUIElement
        let process: NSRunningApplication
    }
    private let queue = DispatchQueue(label: "local.khord.window-cycle")
    private let cancellation = Cancellation()
    private var session = 0 // Main-thread activation identifier, captured with each request.
    private var capturedSession: Int?
    private var entries: [UInt32: Entry] = [:]
    private var order = WindowCycleOrder(windows: [], current: nil)
    var report: ((String) -> Void)?

    func beginSession() { session &+= 1 }
    func cancel() {
        cancellation.cancel()
        beginSession()
        queue.async { [weak self] in
            self?.entries.removeAll()
            self?.order = WindowCycleOrder(windows: [], current: nil)
            self?.capturedSession = nil
        }
    }
    private func token() -> Int { cancellation.current }
    private func notify(_ message: String, ticket: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.token() == ticket else { return }
            self.report?(message)
        }
    }
    func perform(forward: Bool) {
        let requestedSession = session
        let ticket = token()
        let focusedPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let processes = Dictionary(uniqueKeysWithValues: NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isHidden && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .map { ($0.processIdentifier, $0) })
        queue.async { [weak self] in
            guard let self, self.token() == ticket else { return }
            if self.capturedSession != requestedSession {
                self.capture(processes: processes, focusedPID: focusedPID, ticket: ticket)
                guard self.token() == ticket else { return }
                self.capturedSession = requestedSession
            }
            guard !self.order.ids.isEmpty else {
                self.notify("No eligible windows", ticket: ticket); return
            }
            if self.order.ids.count == 1 && self.order.current == self.order.ids.first {
                self.notify("No other eligible windows", ticket: ticket); return
            }
            let visibleOwners = Dictionary(uniqueKeysWithValues: self.visibleWindows().map { ($0.id, $0.pid) })
            // Closed, minimized, hidden, or moved-to-another-Space windows are skipped.
            for _ in self.order.ids {
                guard self.token() == ticket, let id = self.order.next(forward: forward) else { return }
                guard let entry = self.entries[id], visibleOwners[id] == entry.visible.pid,
                      !entry.process.isTerminated,
                      (AXAccess.read(entry.window, kAXMinimizedAttribute) as? Bool) != true else { continue }
                var activated = false
                DispatchQueue.main.sync {
                    guard self.token() == ticket else { return }
                    activated = entry.process.activate(options: [])
                }
                guard self.token() == ticket else { return }
                guard activated else { continue }
                _ = AXUIElementSetAttributeValue(entry.app, kAXFocusedWindowAttribute as CFString, entry.window)
                _ = AXUIElementSetAttributeValue(entry.window, kAXMainAttribute as CFString, kCFBooleanTrue)
                let raised = AXUIElementPerformAction(entry.window, kAXRaiseAction as CFString)
                if raised == .success {
                    self.notify("Focused window \(self.order.position ?? 1) of \(self.order.ids.count)", ticket: ticket)
                    return
                }
            }
            self.notify("No other accessible windows", ticket: ticket)
        }
    }
    private func capture(processes: [pid_t: NSRunningApplication], focusedPID: pid_t?, ticket: Int) {
        entries.removeAll()
        let allVisible = visibleWindows()
        let groups = Dictionary(grouping: allVisible.filter { processes[$0.pid] != nil }, by: { $0.pid })
        var current: UInt32?
        var focusedWindowKnown = false
        for pid in groups.keys.sorted() {
            guard token() == ticket, let process = processes[pid] else { return }
            let app = AXAccess.application(pid)
            let focused = pid == focusedPID ? AXAccess.read(app, kAXFocusedWindowAttribute) : nil
            if pid == focusedPID && focused != nil { focusedWindowKnown = true }
            guard let windows = AXAccess.read(app, kAXWindowsAttribute) as? [AXUIElement] else { continue }
            var available = (groups[pid] ?? []).sorted { $0.id < $1.id }
            for window in windows {
                if available.isEmpty { break }
                guard token() == ticket else { return }
                AXUIElementSetMessagingTimeout(window, 0.2)
                guard (AXAccess.read(window, kAXMinimizedAttribute) as? Bool) != true,
                      let rect = AXAccess.frame(window), rect.width > 0, rect.height > 0 else { continue }
                let subrole = AXAccess.read(window, kAXSubroleAttribute) as? String
                guard subrole == nil || subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole else { continue }
                let number = (AXAccess.read(window, "AXWindowNumber") as? NSNumber)?.uint32Value
                let match: Int?
                if let number {
                    match = available.firstIndex { $0.id == number }
                } else {
                    // AXWindowNumber and CG titles are not exposed by every app. Match
                    // public window geometry one-to-one, using titles when available.
                    let candidates = available.indices.filter { WindowLayout.close(available[$0].frame, rect, tolerance: 3) }
                    let title = candidates.count > 1 && candidates.contains(where: { available[$0].title != nil })
                        ? AXAccess.read(window, kAXTitleAttribute) as? String : nil
                    match = candidates.first { index in
                        guard let title, !title.isEmpty, let cgTitle = available[index].title else { return false }
                        return title == cgTitle
                    } ?? candidates.first
                }
                guard let index = match else { continue }
                let record = available.remove(at: index)
                entries[record.id] = Entry(visible: record, window: window, app: app, process: process)
                if pid == focusedPID, let focused, CFEqual(focused, window) { current = record.id }
            }
        }
        if current == nil && !focusedWindowKnown {
            if let frontmost = allVisible.first(where: { $0.pid == focusedPID }), entries[frontmost.id] != nil {
                current = frontmost.id
            }
        }
        order = WindowCycleOrder(windows: entries.values.map { CycleWindowPosition(id: $0.visible.id, frame: $0.visible.frame) }, current: current)
    }
    private func visibleWindows() -> [VisibleWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard (item[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  ((item[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0,
                  let id = (item[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let pid = (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary), frame.origin.x.isFinite, frame.origin.y.isFinite, frame.width.isFinite, frame.height.isFinite, frame.width > 0, frame.height > 0 else { return nil }
            return VisibleWindow(id: id, pid: pid, frame: frame, title: item[kCGWindowName as String] as? String)
        }
    }
}
