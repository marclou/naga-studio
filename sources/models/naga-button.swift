import Foundation

nonisolated enum TiltDirection: String, Codable, Sendable {
    case left, right
}

/// A raw input the Naga sends to the Mac over Bluetooth.
nonisolated enum NagaInput: Hashable, Codable, Sendable {
    case key(UInt16)
    case mouse(Int)
    case tilt(TiltDirection)
}

nonisolated enum NagaButton: String, CaseIterable, Codable, CodingKeyRepresentable, Identifiable, Sendable {
    case side1, side2, side3, side4, side5, side6, side7, side8, side9, side10, side11, side12
    case leftClick, rightClick, wheelClick, tiltLeft, tiltRight
    case dpiUp, dpiDown, scrollMode, aiPrompt, ringFinger

    static let side: [NagaButton] = [.side1, .side2, .side3, .side4, .side5, .side6, .side7, .side8, .side9, .side10, .side11, .side12]
    static let top: [NagaButton] = [.leftClick, .rightClick, .wheelClick, .tiltLeft, .tiltRight, .dpiUp, .dpiDown, .scrollMode, .aiPrompt, .ringFinger]

    /// Keys the 12-button plate sends by default: 1 to 9, 0, minus and equals.
    private static let sideKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24]
    private static let sideKeypadCodes: [UInt16] = [83, 84, 85, 86, 87, 88, 89, 91, 92, 82, 78, 69]
    private static let sideKeyLabels = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]

    var id: String { rawValue }

    var sideNumber: Int? { Self.side.firstIndex(of: self).map { $0 + 1 } }

    var isSide: Bool { sideNumber != nil }

    var title: String {
        if let sideNumber { return "Button \(sideNumber)" }
        return switch self {
        case .leftClick: "Left click"
        case .rightClick: "Right click"
        case .wheelClick: "Wheel click"
        case .tiltLeft: "Wheel tilt left"
        case .tiltRight: "Wheel tilt right"
        case .dpiUp: "DPI up"
        case .dpiDown: "DPI down"
        case .scrollMode: "Scroll mode"
        case .aiPrompt: "AI prompt button"
        case .ringFinger: "Ring finger button"
        default: rawValue
        }
    }

    var defaultInputs: [NagaInput] {
        if let index = Self.side.firstIndex(of: self) {
            return [.key(Self.sideKeyCodes[index]), .key(Self.sideKeypadCodes[index])]
        }
        return switch self {
        case .leftClick: [.mouse(0)]
        case .rightClick: [.mouse(1)]
        case .wheelClick: [.mouse(2)]
        case .tiltLeft: [.tilt(.left)]
        case .tiltRight: [.tilt(.right)]
        default: []
        }
    }

    /// What the button does when nothing is remapped.
    var defaultBehavior: String {
        if let index = Self.side.firstIndex(of: self) { return "Types \(Self.sideKeyLabels[index])" }
        return switch self {
        case .leftClick: "Left click"
        case .rightClick: "Right click"
        case .wheelClick: "Middle click"
        case .tiltLeft: "Scrolls left"
        case .tiltRight: "Scrolls right"
        case .dpiUp: "Raises DPI"
        case .dpiDown: "Lowers DPI"
        case .scrollMode: "Free-spin toggle"
        case .aiPrompt: "Needs Synapse"
        case .ringFinger: "Hypershift"
        default: ""
        }
    }

    var isLocked: Bool { self == .leftClick }

    var hardwareNote: String? {
        switch self {
        case .leftClick: "Left click always stays a left click, so you can never lock yourself out."
        case .dpiUp, .dpiDown: "The mouse changes DPI by itself and usually sends nothing to your Mac. Detect it to check."
        case .scrollMode: "The mouse switches scroll modes by itself and usually sends nothing to your Mac. Detect it to check."
        case .aiPrompt: "Without Razer Synapse this button usually sends nothing. Detect it to check."
        case .ringFinger: "Unlock it with the toggle under the mouse, then detect it to check what it sends."
        default: nil
        }
    }
}
