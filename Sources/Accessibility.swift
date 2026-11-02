import ApplicationServices

// Shared, type-checked AX access. No calls are made on the event-tap path.
enum AXAccess {
    static func application(_ pid: pid_t, timeout: Float = 0.2) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, timeout)
        return app
    }
    static func read(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        readResult(element, attribute).value
    }
    static func readResult(_ element: AXUIElement, _ attribute: String) -> (value: CFTypeRef?, error: AXError) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return (error == .success ? value : nil, error)
    }
    static func errorDescription(_ error: AXError) -> String {
        switch error {
        case .success: return "success (0)"
        case .cannotComplete: return "could not complete/possible timeout (\(error.rawValue))"
        case .attributeUnsupported: return "attribute unsupported (\(error.rawValue))"
        case .noValue: return "no value (\(error.rawValue))"
        case .invalidUIElement: return "invalid window/control reference (\(error.rawValue))"
        case .apiDisabled: return "accessibility API disabled (\(error.rawValue))"
        default: return "AX error \(error.rawValue)"
        }
    }
    static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
    static func frame(_ element: AXUIElement) -> CGRect? {
        decodeFrame(position: read(element, kAXPositionAttribute), size: read(element, kAXSizeAttribute))
    }
    static func decodeFrame(position: CFTypeRef?, size: CFTypeRef?) -> CGRect? {
        guard let p = position, let s = size,
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        let position = unsafeBitCast(p, to: AXValue.self)
        let dimensions = unsafeBitCast(s, to: AXValue.self)
        guard AXValueGetType(position) == .cgPoint, AXValueGetType(dimensions) == .cgSize else { return nil }
        var point = CGPoint.zero; var size = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(dimensions, .cgSize, &size),
              point.x.isFinite, point.y.isFinite, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: point, size: size)
    }
    static func setFrame(_ window: AXUIElement, _ frame: CGRect, finalize: Bool = true) -> AXError {
        var point = frame.origin; var size = frame.size
        guard let p = AXValueCreate(.cgPoint, &point), let s = AXValueCreate(.cgSize, &size) else { return .failure }
        let resize = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s)
        let move = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, p)
        // Intermediate animation frames need only two messages. Final sizing gets a
        // second attempt after moving, for apps that clamp at the original display edge.
        let finalSize = finalize ? AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s) : resize
        return move != .success ? move : finalSize
    }
}
