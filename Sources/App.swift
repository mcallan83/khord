import AppKit
import ApplicationServices

private let callback: CGEventTapCallBack = { proxy, type, event, context in
    guard let context else { return Unmanaged.passUnretained(event) }
    return Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
        .receive(proxy: proxy, type: type, event: event)
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let launchAtLogin = LaunchAtLogin()
    var status: NSStatusItem!
    let windows = WindowManager()
    let cycler = WindowCycler()
    let menuIcon = KhordIcon.menu()
    let activeMenuIcon = KhordIcon.menu(active: true)
    var lastWindowAction = "No window action yet"
    var tap: CFMachPort?
    var source: CFRunLoopSource?
    var chord = Chord()
    var startupGate = StartupKeyGate()
    var startupHeldKeys = Set<UInt16>()
    var buffered: CGEvent?
    var timer: Timer?
    var enabled = true
    var health: Timer?
    var syntheticModifiers: LayerModifiers = []
    private var eventGeneration = 0
    private var updateScheduled = false
    var waitingToStart = true
    var reason = "Starting…"
    let toggleItem = NSMenuItem(title: "Disable", action: nil, keyEquivalent: "")
    var statusMessage = "Starting…"
    let tag: Int64 = 0x53445052

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        menu.showsStateColumn = false
        windows.report = { [weak self] message in self?.lastWindowAction = message }
        cycler.report = { [weak self] message in self?.lastWindowAction = message }
        toggleItem.action = #selector(toggle)
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLogin.item)
        menu.addItem(.separator())
        for (title, action) in [("Open Accessibility Settings", #selector(settings)),
                                 ("Show Diagnostics", #selector(diagnostics))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        status.menu = menu
        retry()
        health = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let tap = self.tap, !CGEvent.tapIsEnabled(tap: tap) {
                self.stop()
                self.waitingToStart = false
                self.reason = "Keyboard access interrupted — release keys, then disable and enable"
                self.update()
            } else if self.enabled && self.tap == nil && self.waitingToStart {
                self.start(prompt: false)
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleeping),
            name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke),
            name: NSWorkspace.didWakeNotification, object: nil)
    }
    func menuWillOpen(_ menu: NSMenu) { launchAtLogin.refresh() }
    private func scheduleUpdate() {
        guard !updateScheduled else { return }
        updateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            self.update()
        }
    }
    func update() {
        toggleItem.title = enabled ? "Disable" : "Enable"
        let active = enabled && tap != nil && chord.active
        let title = !enabled ? "⏸" : tap == nil ? "!" : ""
        status.button?.image = active ? activeMenuIcon : menuIcon
        status.button?.imagePosition = .imageLeading
        status.button?.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: active ? NSColor.systemGreen : NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: active ? .bold : .regular)
        ])
        statusMessage = !enabled ? "Paused" : tap == nil ? reason : active ? "\(KhordDefaults.activationLabel) active" : "Ready — hold \(KhordDefaults.activationLabel)"
        status.button?.toolTip = "Khord — " + statusMessage
    }
    @objc func retry() {
        waitingToStart = true
        start(prompt: true)
    }
    func start(prompt: Bool) {
        guard enabled else { update(); return }
        guard tap == nil else { update(); return }
        // Re-query without prompting during automatic retries.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        let relevant = Set(KhordDefaults.activationCodes + KhordDefaults.layerKeys)
        startupHeldKeys = Set(relevant.filter { CGEventSource.keyState(.hidSystemState, key: $0) })
        startupGate = StartupKeyGate(heldAtStartup: startupHeldKeys)
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let createdTap = tap {
            if let createdSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0) {
                source = createdSource
                CFRunLoopAddSource(CFRunLoopGetMain(), createdSource, .commonModes)
                CGEvent.tapEnable(tap: createdTap, enable: true)
                eventGeneration &+= 1
            } else {
                CFMachPortInvalidate(createdTap)
                tap = nil
            }
        }
        if tap != nil {
            waitingToStart = false
            reason = "Ready"
        } else {
            reason = trusted ? "Permission recognized; keyboard event tap failed — restart app" : "macOS has not authorized this running copy — check app path"
            if prompt && !trusted {
                let request = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(request)
            }
        }
        update()
    }
    func keyNames(_ keys: Set<UInt16>) -> String {
        if keys.isEmpty { return "None" }
        return keys.sorted().map { code in
            KhordDefaults.keyNames[code] ?? "Key \(code)"
        }.joined(separator: ", ")
    }
    @objc func diagnostics() {
        let alert = NSAlert()
        alert.messageText = "Khord Status"
        alert.informativeText = "\(statusMessage)\n\nKeys held at startup (hardware): \(keyNames(startupHeldKeys))\nHeld keys awaiting release/new press: \(keyNames(startupGate.remaining))\n\nWindow action: \(lastWindowAction)\n\nRunning app:\n\(Bundle.main.bundlePath)\n\nAccessibility recognized: \(AXIsProcessTrusted() ? "Yes" : "No")\nKeyboard event tap: \(tap == nil ? "Not running" : "Running")"
        alert.runModal()
    }
    func receive(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Fail open after interruption; user can retry once keys are released.
            let generation = eventGeneration
            DispatchQueue.main.async { [weak self] in
                guard let self, self.eventGeneration == generation else { return }
                self.stop(); self.waitingToStart = false
                self.reason = "Keyboard access interrupted — release keys, then disable and enable"
                self.update()
            }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == tag { return Unmanaged.passUnretained(event) }
        let key = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .flagsChanged {
            flush(proxy: proxy); chord.expire()
            event.flags.formUnion(cgFlags(syntheticModifiers))
            return Unmanaged.passUnretained(event)
        }
        guard let input = KeyboardInput.decode(type: type, code: key, flags: event.flags,
            repeating: event.getIntegerValueField(.keyboardEventAutorepeat) != 0, timestamp: event.timestamp) else {
            return Unmanaged.passUnretained(event)
        }
        guard startupGate.accepts(input) else {
            // Preserve a key already held before interception; do not remap its repeats or release.
            event.flags.formUnion(cgFlags(syntheticModifiers))
            return Unmanaged.passUnretained(event)
        }
        let wasActive = chord.active
        let decisions = chord.handle(input)
        if chord.active != wasActive {
            if chord.active { cycler.beginSession() }
            scheduleUpdate()
        }
        for decision in decisions {
            switch decision {
            case .cycleWindow(let forward):
                let generation = eventGeneration
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.enabled, self.tap != nil, self.eventGeneration == generation else { return }
                    self.cycler.perform(forward: forward)
                }
                return nil
            case .window(let command):
                let generation = eventGeneration
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.enabled, self.tap != nil, self.eventGeneration == generation else { return }
                    self.windows.perform(command)
                }
                return nil
            case .replay: flush(proxy: proxy)
            case .buffer:
                buffered = event.copy()
                timer?.invalidate()
                timer = Timer(timeInterval: KhordDefaults.chordWindowMs / 1000, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.flush(); self.chord.expire()
                }
                RunLoop.main.add(timer!, forMode: .common)
                return nil
            case .discardBuffer:
                timer?.invalidate(); timer = nil; buffered = nil
            case .suppress:
                return nil
            case .modifiers(let modifiers):
                setModifiers(modifiers, physical: physicalFlags(event), proxy: proxy)
            case .emit(let output):
                guard let replacement = CGEvent(keyboardEventSource: nil, virtualKey: output.code, keyDown: input.down) else { return nil }
                let physical = physicalFlags(event)
                replacement.flags = output.exact ? cgFlags(output.modifiers) : physical.union(cgFlags(output.modifiers))
                replacement.setIntegerValueField(.keyboardEventAutorepeat, value: event.getIntegerValueField(.keyboardEventAutorepeat))
                replacement.setIntegerValueField(.eventSourceUserData, value: tag)
                replacement.tapPostEvent(proxy)
                return nil
            case .pass:
                event.flags.formUnion(cgFlags(syntheticModifiers))
                return Unmanaged.passUnretained(event)
            }
        }
        return Unmanaged.passUnretained(event)
    }
    func physicalFlags(_ event: CGEvent) -> CGEventFlags {
        let physicalModifiers = CGEventSource.flagsState(.hidSystemState)
            .intersection([.maskAlternate, .maskCommand, .maskShift])
        return event.flags.subtracting(cgFlags(syntheticModifiers)).union(physicalModifiers)
    }
    func cgFlags(_ modifiers: LayerModifiers) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        return flags
    }
    func setModifiers(_ modifiers: LayerModifiers, physical: CGEventFlags, proxy: CGEventTapProxy? = nil) {
        for (modifier, code): (LayerModifiers, CGKeyCode) in [(.option, 58), (.command, 55), (.shift, 56)] {
            guard syntheticModifiers.contains(modifier) != modifiers.contains(modifier) else { continue }
            if modifiers.contains(modifier) { syntheticModifiers.insert(modifier) }
            else { syntheticModifiers.remove(modifier) }
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: modifiers.contains(modifier)) else { continue }
            event.type = .flagsChanged
            event.flags = physical.union(cgFlags(syntheticModifiers))
            event.setIntegerValueField(.eventSourceUserData, value: tag)
            if let proxy { event.tapPostEvent(proxy) } else { event.post(tap: .cgSessionEventTap) }
        }
    }
    func flush(proxy: CGEventTapProxy? = nil) {
        timer?.invalidate(); timer = nil
        guard let event = buffered else { return }
        buffered = nil
        event.setIntegerValueField(.eventSourceUserData, value: tag)
        if let proxy { event.tapPostEvent(proxy) } else { event.post(tap: .cgSessionEventTap) }
    }
    func stop() {
        eventGeneration &+= 1
        cycler.cancel()
        windows.cancel()
        flush()
        for output in chord.mapped.values {
            if let up = CGEvent(keyboardEventSource: nil, virtualKey: output.code, keyDown: false) {
                up.flags = cgFlags(output.modifiers)
                up.setIntegerValueField(.eventSourceUserData, value: tag)
                up.post(tap: .cgSessionEventTap)
            }
        }
        setModifiers([], physical: CGEventSource.flagsState(.hidSystemState))
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil; tap = nil; chord = Chord()
        startupGate = StartupKeyGate()
    }
    @objc func toggle() { enabled.toggle(); if enabled { retry() } else { stop(); update() } }
    @objc func settings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func sleeping() { stop(); update() }
    @objc func woke() { retry() }
    @objc func quit() { stop(); NSApplication.shared.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { stop() }
}

@main struct Khord {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
