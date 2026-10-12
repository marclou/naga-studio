import AppKit

struct ActionDisplay {
    var title: String
    var detail: String?
    var symbol: String
    var isRemapped: Bool
}

extension AppModel {
    func display(for button: NagaButton) -> ActionDisplay {
        if button.isLocked {
            return ActionDisplay(title: "Left click", detail: "Locked", symbol: "lock.fill", isRemapped: false)
        }
        if !canRemap(button) {
            return ActionDisplay(title: button.defaultBehavior, detail: "Handled by the mouse", symbol: "memorychip", isRemapped: false)
        }
        return action(for: button).display(for: button)
    }
}

@MainActor extension ButtonAction {
    func display(for button: NagaButton) -> ActionDisplay {
        switch self {
        case .original:
            ActionDisplay(title: button.defaultBehavior, detail: "Default", symbol: button.isSide ? "keyboard" : "computermouse", isRemapped: false)
        case .disabled:
            ActionDisplay(title: "Disabled", detail: "Does nothing", symbol: "nosign", isRemapped: true)
        case .click(let click):
            ActionDisplay(title: click.title, detail: "Mouse", symbol: click.symbol, isRemapped: true)
        case .shortcut(let combo):
            ActionDisplay(title: combo.label, detail: "Shortcut", symbol: "command", isRemapped: true)
        case .preset(let preset):
            ActionDisplay(title: preset.title, detail: preset.hint, symbol: preset.symbol, isRemapped: true)
        case .text(let text):
            ActionDisplay(title: "Types “\(text)”", detail: "Text", symbol: "text.cursor", isRemapped: true)
        case .app(let path):
            ActionDisplay(title: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent, detail: "Opens app",
                          symbol: "app.badge", isRemapped: true)
        }
    }
}

@MainActor extension KeyCombo {
    var label: String { modifiers.symbols + KeyboardLayout.name(for: keyCode) }
}

@MainActor extension Preset {
    var hint: String {
        switch effect {
        case let .keys(character, keyCode, modifiers): modifiers.symbols + (character?.uppercased() ?? KeyboardLayout.name(for: keyCode))
        case .dock: "System"
        case .media: "Media key"
        }
    }
}

@MainActor extension NagaInput {
    var label: String {
        switch self {
        case .key(let keyCode): "Key \(KeyboardLayout.name(for: keyCode))"
        case .mouse(let number): ["Left click", "Right click", "Middle click"].indices.contains(number)
            ? ["Left click", "Right click", "Middle click"][number]
            : "Mouse button \(number + 1)"
        case .tilt(let direction): direction == .left ? "Tilt left" : "Tilt right"
        }
    }
}

@MainActor extension ModifierSet {
    init(_ flags: NSEvent.ModifierFlags) {
        var set: ModifierSet = []
        if flags.contains(.control) { set.insert(.control) }
        if flags.contains(.option) { set.insert(.option) }
        if flags.contains(.shift) { set.insert(.shift) }
        if flags.contains(.command) { set.insert(.command) }
        self = set
    }
}
