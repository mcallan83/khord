import AppKit
import ServiceManagement

final class LaunchAtLogin: NSObject {
    let item = NSMenuItem(title: "Launch At Login", action: nil, keyEquivalent: "")
    private let service = SMAppService.mainApp

    override init() {
        super.init()
        item.target = self
        item.action = #selector(toggle)
        refresh()
    }
    func refresh() {
        // Only show a check when macOS confirms that this app is eligible to run.
        let status = service.status
        let enabled = status == .enabled
        item.title = enabled ? "Launch At Login ✓" : "Launch At Login"
        item.state = .off // Keep AppKit's leading state/checkmark column unused.
        let help = status == .requiresApproval ? "Approval is needed in System Settings → General → Login Items." : "Open Khord automatically when you log in to your Mac."
        item.toolTip = help
    }
    @objc private func toggle() {
        item.menu?.cancelTracking()
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                showApproval()
                refresh()
                return
            case .notRegistered, .notFound:
                try service.register()
            @unknown default:
                try service.register()
            }
            refresh()
            if service.status == .requiresApproval { showApproval(); refresh() }
        } catch {
            refresh()
            let alert = NSAlert()
            alert.messageText = "Could Not Update Launch At Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
    private func showApproval() {
        let alert = NSAlert()
        alert.messageText = "Allow Khord to Launch At Login"
        alert.informativeText = "macOS needs your approval in System Settings → General → Login Items. The checkmark appears once Khord is enabled there."
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "Turn Off")
        alert.addButton(withTitle: "Not Now")
        switch alert.runModal() {
        case .alertFirstButtonReturn: SMAppService.openSystemSettingsLoginItems()
        case .alertSecondButtonReturn:
            do { try service.unregister() }
            catch {
                let failure = NSAlert()
                failure.messageText = "Could Not Turn Off Launch At Login"
                failure.informativeText = error.localizedDescription
                failure.runModal()
            }
        default: break
        }
    }
}
