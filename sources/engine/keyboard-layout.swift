import Carbon.HIToolbox
import Foundation

enum KeyboardLayout {
    private static let specialKeyNames: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc", 117: "Forward delete", 76: "Enter",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "Home", 119: "End", 116: "Page up", 121: "Page down",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
        65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 71: "Clear", 75: "Keypad /", 78: "Keypad -", 81: "Keypad =",
        82: "Keypad 0", 83: "Keypad 1", 84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4",
        87: "Keypad 5", 88: "Keypad 6", 89: "Keypad 7", 91: "Keypad 8", 92: "Keypad 9",
    ]

    static func name(for keyCode: UInt16) -> String {
        if let name = specialKeyNames[keyCode] { return name }
        return withCurrentLayout { character(for: keyCode, in: $0) }??.uppercased() ?? "Key \(keyCode)"
    }

    /// Character → key code for the active layout, so ⌘Z stays ⌘Z on AZERTY and other layouts.
    static func reverseMap() -> [String: UInt16] {
        withCurrentLayout { layout in
            var map: [String: UInt16] = [:]
            for keyCode in UInt16(0)..<128 where specialKeyNames[keyCode] == nil {
                guard let character = character(for: keyCode, in: layout)?.lowercased(), map[character] == nil else { continue }
                map[character] = keyCode
            }
            return map
        } ?? [:]
    }

    private static func withCurrentLayout<Result>(_ body: (UnsafePointer<UCKeyboardLayout>) -> Result) -> Result? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer in
            buffer.baseAddress.map { body($0.assumingMemoryBound(to: UCKeyboardLayout.self)) }
        }
    }

    private static func character(for keyCode: UInt16, in layout: UnsafePointer<UCKeyboardLayout>) -> String? {
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState,
                                    characters.count, &length, &characters)
        guard status == noErr, length > 0 else { return nil }
        let string = String(utf16CodeUnits: characters, count: length)
        return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : string
    }
}
