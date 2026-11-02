import ApplicationServices

enum WindowFrameSettlement {
    // At most 0.6 seconds of settling, plus AX messaging timeouts. Two matching
    // observations avoid treating a transient frame as a completed update.
    static func finish(target: CGRect, initialError: AXError,
                       cancelled: () -> Bool, read: () -> CGRect?,
                       write: () -> AXError, pause: () -> Void) -> AXError {
        var error = initialError
        var matches = 0
        for observation in 0..<12 {
            guard !cancelled() else { return .failure }
            pause()
            guard !cancelled() else { return .failure }
            if let frame = read(), WindowLayout.close(frame, target, tolerance: 2) {
                matches += 1
                if matches >= 2 { return .success }
            } else {
                matches = 0
                if observation == 3 || observation == 7 {
                    guard !cancelled() else { return .failure }
                    error = write()
                }
            }
        }
        return error
    }
}
