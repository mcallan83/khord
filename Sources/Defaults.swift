// Fixed behavior for Khord. No configuration files are read or created.
enum KhordDefaults {
    static let activationCodes: [UInt16] = [1, 2] // S + D
    static let activationLabel = "S+D"
    static let chordWindowMs = 60.0
    static let animationDurationMs = 100.0
    static let readingWidthPx = 1100.0
    static let tileLeftWidths = [50.0, 30.0, 70.0]
    static let tileRightWidths = [50.0, 70.0, 30.0]
    static let layerKeys: [UInt16] = [
        4, 38, 40, 37, // H/J/K/L navigation
        0, 3, 49, // A/F/Space modifiers
        34, 31, 32, 35, // I/O/U/P tabs
        11, 45, 15, 51, // B/N/R/Backspace
        36, 126, 125, 8, // Enter/Up/Down/C windows
        43, 47, // Comma/period: previous/next window
        123, 124, 33, 30 // Left/Right/[ / ] layouts/displays
    ]
    static let keyNames: [UInt16: String] = [
        0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 8:"C", 11:"B", 15:"R",
        30:"]", 31:"O", 32:"U", 33:"[", 34:"I", 35:"P", 36:"Enter", 37:"L",
        38:"J", 40:"K", 43:",", 45:"N", 47:".", 49:"Space", 51:"Backspace", 63:"Fn/Globe",
        123:"Left", 124:"Right", 125:"Down", 126:"Up"
    ]
}
