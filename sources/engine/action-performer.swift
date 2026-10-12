import AppKit
import CoreGraphics
import os

/// An action resolved for the event tap thread: no layout lookups or UI state left.
nonisolated enum EngineAction: Sendable, Equatable {
    case swallow
    case keys(keyCode: UInt16, modifiers: ModifierSet)
    case click(MouseClick)
    case dock(String)
    case media(Int32)
    case text(String)
    case openApp(String)
}

nonisolated enum ActionPhase: Sendable {
    case down, up, repeated
}

nonisolated struct ActionPerformer: Sendable {
    static let syntheticMarker: Int64 = 0x4E41_4741

    private static let modifierKeys: [(modifier: ModifierSet, keyCode: UInt16, flag: CGEventFlags)] = [
        (.control, 59, .maskControl),
        (.option, 58, .maskAlternate),
        (.shift, 56, .maskShift),
        (.command, 55, .maskCommand),
    ]

    func perform(_ action: EngineAction, phase: ActionPhase) {
        switch action {
        case .swallow:
            return
        case let .keys(keyCode, modifiers):
            postShortcut(keyCode: keyCode, modifiers: modifiers, phase: phase)
        case .click(let click):
            postClick(click, phase: phase)
        case .dock(let notification):
            guard phase == .down else { return }
            Task { @MainActor in Self.sendDockNotification(notification) }
        case .media(let key):
            guard phase == .down else { return }
            Task { @MainActor in Self.postMediaKey(key) }
        case .text(let text):
            guard phase == .down else { return }
            type(text)
        case .openApp(let path):
            guard phase == .down else { return }
            Task { @MainActor in Self.openApp(at: path) }
        }
    }

    private func postShortcut(keyCode: UInt16, modifiers: ModifierSet, phase: ActionPhase) {
        let source = CGEventSource(stateID: .privateState)
        let held = Self.modifierKeys.filter { modifiers.contains($0.modifier) }
        let keyFlags = modifiers.cgFlags.union(Self.implicitFlags(for: keyCode))
        switch phase {
        case .down:
            var flags: CGEventFlags = []
            for key in held {
                flags.insert(key.flag)
                postKey(key.keyCode, isDown: true, flags: flags, source: source, isModifier: true)
            }
            postKey(keyCode, isDown: true, flags: keyFlags, source: source)
        case .repeated:
            postKey(keyCode, isDown: true, flags: keyFlags, source: source, isRepeat: true)
        case .up:
            postKey(keyCode, isDown: false, flags: keyFlags, source: source)
            var flags = modifiers.cgFlags
            for key in held.reversed() {
                flags.remove(key.flag)
                postKey(key.keyCode, isDown: false, flags: flags, source: source, isModifier: true)
            }
        }
    }

    private func postKey(_ keyCode: UInt16, isDown: Bool, flags: CGEventFlags, source: CGEventSource?,
                         isModifier: Bool = false, isRepeat: Bool = false) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { return }
        if isModifier { event.type = .flagsChanged }
        event.flags = flags
        if isRepeat { event.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
        Self.post(event)
    }

    /// Arrow, navigation and function keys carry these flags when typed on a real keyboard.
    private static func implicitFlags(for keyCode: UInt16) -> CGEventFlags {
        switch keyCode {
        case 123...126: [.maskSecondaryFn, .maskNumericPad]
        case 96...122: [.maskSecondaryFn]
        default: []
        }
    }

    private func postClick(_ click: MouseClick, phase: ActionPhase) {
        guard phase != .repeated else { return }
        let location = CGEvent(source: nil)?.location ?? .zero
        let isDown = phase == .down
        switch click {
        case .left:
            postMouse(isDown ? .leftMouseDown : .leftMouseUp, button: .left, number: 0, at: location)
        case .right:
            postMouse(isDown ? .rightMouseDown : .rightMouseUp, button: .right, number: 1, at: location)
        case .middle:
            postMouse(isDown ? .otherMouseDown : .otherMouseUp, button: .center, number: 2, at: location)
        case .back:
            postMouse(isDown ? .otherMouseDown : .otherMouseUp, button: .center, number: 3, at: location)
        case .forward:
            postMouse(isDown ? .otherMouseDown : .otherMouseUp, button: .center, number: 4, at: location)
        case .double:
            guard isDown else { return }
            for clickState: Int64 in [1, 2] {
                postMouse(.leftMouseDown, button: .left, number: 0, at: location, clickState: clickState)
                postMouse(.leftMouseUp, button: .left, number: 0, at: location, clickState: clickState)
            }
        }
    }

    private func postMouse(_ type: CGEventType, button: CGMouseButton, number: Int64, at location: CGPoint, clickState: Int64 = 1) {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventButtonNumber, value: number)
        event.setIntegerValueField(.mouseEventClickState, value: clickState)
        Self.post(event)
    }

    private func type(_ text: String) {
        let units = Array(text.utf16)
        // Apps drop unicode payloads longer than about 20 UTF-16 units per event.
        for start in stride(from: 0, to: units.count, by: 20) {
            let chunk = Array(units[start..<min(start + 20, units.count)])
            for isDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: isDown) else { continue }
                chunk.withUnsafeBufferPointer { event.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: $0.baseAddress) }
                event.flags = []
                Self.post(event)
            }
        }
    }

    private static func post(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        event.post(tap: .cghidEventTap)
    }

    @MainActor private static func postMediaKey(_ key: Int32) {
        for isDown in [true, false] {
            let state = isDown ? 0xA : 0xB
            guard let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                                 modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                                                 timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
                                                 data1: Int(key) << 16 | state << 8, data2: -1)?.cgEvent else { continue }
            post(event)
        }
    }

    private typealias DockNotification = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void

    @MainActor private static func sendDockNotification(_ name: String) {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CoreDockSendNotification") else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
            return
        }
        unsafeBitCast(symbol, to: DockNotification.self)(name as CFString, nil)
    }

    @MainActor private static func openApp(at path: String) {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { logger.error("Could not open \(path, privacy: .public): \(error.localizedDescription, privacy: .public)") }
        }
    }

    private static let logger = Logger(subsystem: "com.marclou.naga-studio", category: "actions")
}
