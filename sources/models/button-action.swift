import CoreGraphics
import Foundation

nonisolated struct ModifierSet: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int

    static let control = ModifierSet(rawValue: 1 << 0)
    static let option = ModifierSet(rawValue: 1 << 1)
    static let shift = ModifierSet(rawValue: 1 << 2)
    static let command = ModifierSet(rawValue: 1 << 3)

    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.command) { flags.insert(.maskCommand) }
        return flags
    }

    var symbols: String {
        [(ModifierSet.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .filter { contains($0.0) }
            .map(\.1)
            .joined()
    }
}

nonisolated struct KeyCombo: Codable, Hashable, Sendable {
    var keyCode: UInt16
    var modifiers: ModifierSet
}

nonisolated enum MouseClick: String, Codable, CaseIterable, Sendable {
    case left, right, middle, back, forward, double

    var title: String {
        switch self {
        case .left: "Left click"
        case .right: "Right click"
        case .middle: "Middle click"
        case .back: "Back button"
        case .forward: "Forward button"
        case .double: "Double click"
        }
    }

    var symbol: String {
        switch self {
        case .left: "cursorarrow.click"
        case .right: "contextualmenu.and.cursorarrow"
        case .middle: "computermouse"
        case .back: "arrow.backward.circle"
        case .forward: "arrow.forward.circle"
        case .double: "cursorarrow.click.2"
        }
    }
}

nonisolated enum ActionCategory: String, CaseIterable, Sendable {
    case edit, browsing, system, media

    var title: String {
        switch self {
        case .edit: "Editing"
        case .browsing: "Apps and tabs"
        case .system: "System"
        case .media: "Media"
        }
    }
}

nonisolated enum PresetEffect: Sendable {
    /// `character` is looked up in the active keyboard layout so menu shortcuts work on any layout.
    case keys(character: String?, keyCode: UInt16, modifiers: ModifierSet)
    case dock(String)
    case media(Int32)
}

nonisolated enum Preset: String, Codable, CaseIterable, Identifiable, Sendable {
    case copy, paste, cut, undo, redo, selectAll, find, save
    case previousApp, newTab, closeTab, reopenTab, nextTab, previousTab, navigateBack, navigateForward
    case missionControl, appWindows, showDesktop, spotlight, screenshot, lockScreen, desktopLeft, desktopRight
    case playPause, nextTrack, previousTrack, volumeUp, volumeDown, mute

    var id: String { rawValue }

    var category: ActionCategory {
        switch self {
        case .copy, .paste, .cut, .undo, .redo, .selectAll, .find, .save: .edit
        case .previousApp, .newTab, .closeTab, .reopenTab, .nextTab, .previousTab, .navigateBack, .navigateForward: .browsing
        case .missionControl, .appWindows, .showDesktop, .spotlight, .screenshot, .lockScreen, .desktopLeft, .desktopRight: .system
        case .playPause, .nextTrack, .previousTrack, .volumeUp, .volumeDown, .mute: .media
        }
    }

    var title: String {
        switch self {
        case .copy: "Copy"
        case .paste: "Paste"
        case .cut: "Cut"
        case .undo: "Undo"
        case .redo: "Redo"
        case .selectAll: "Select all"
        case .find: "Find"
        case .save: "Save"
        case .previousApp: "Previous app"
        case .newTab: "New tab"
        case .closeTab: "Close tab"
        case .reopenTab: "Reopen tab"
        case .nextTab: "Next tab"
        case .previousTab: "Previous tab"
        case .navigateBack: "Go back"
        case .navigateForward: "Go forward"
        case .missionControl: "Mission Control"
        case .appWindows: "App windows"
        case .showDesktop: "Show desktop"
        case .spotlight: "Spotlight"
        case .screenshot: "Screenshot"
        case .lockScreen: "Lock screen"
        case .desktopLeft: "Desktop left"
        case .desktopRight: "Desktop right"
        case .playPause: "Play or pause"
        case .nextTrack: "Next track"
        case .previousTrack: "Previous track"
        case .volumeUp: "Volume up"
        case .volumeDown: "Volume down"
        case .mute: "Mute"
        }
    }

    var symbol: String {
        switch self {
        case .copy: "doc.on.doc"
        case .paste: "doc.on.clipboard"
        case .cut: "scissors"
        case .undo: "arrow.uturn.backward"
        case .redo: "arrow.uturn.forward"
        case .selectAll: "selection.pin.in.out"
        case .find: "magnifyingglass"
        case .save: "square.and.arrow.down"
        case .previousApp: "arrow.left.arrow.right.square"
        case .newTab: "plus.square.on.square"
        case .closeTab: "xmark.square"
        case .reopenTab: "arrow.counterclockwise"
        case .nextTab: "chevron.right.square"
        case .previousTab: "chevron.left.square"
        case .navigateBack: "chevron.backward"
        case .navigateForward: "chevron.forward"
        case .missionControl: "rectangle.3.group"
        case .appWindows: "macwindow.on.rectangle"
        case .showDesktop: "menubar.dock.rectangle"
        case .spotlight: "magnifyingglass.circle"
        case .screenshot: "camera.viewfinder"
        case .lockScreen: "lock"
        case .desktopLeft: "rectangle.lefthalf.inset.filled.arrow.left"
        case .desktopRight: "rectangle.righthalf.inset.filled.arrow.right"
        case .playPause: "playpause.fill"
        case .nextTrack: "forward.end.fill"
        case .previousTrack: "backward.end.fill"
        case .volumeUp: "speaker.wave.3.fill"
        case .volumeDown: "speaker.wave.1.fill"
        case .mute: "speaker.slash.fill"
        }
    }

    var effect: PresetEffect {
        switch self {
        case .copy: .keys(character: "c", keyCode: 8, modifiers: .command)
        case .paste: .keys(character: "v", keyCode: 9, modifiers: .command)
        case .cut: .keys(character: "x", keyCode: 7, modifiers: .command)
        case .undo: .keys(character: "z", keyCode: 6, modifiers: .command)
        case .redo: .keys(character: "z", keyCode: 6, modifiers: [.command, .shift])
        case .selectAll: .keys(character: "a", keyCode: 0, modifiers: .command)
        case .find: .keys(character: "f", keyCode: 3, modifiers: .command)
        case .save: .keys(character: "s", keyCode: 1, modifiers: .command)
        case .previousApp: .keys(character: nil, keyCode: 48, modifiers: .command)
        case .newTab: .keys(character: "t", keyCode: 17, modifiers: .command)
        case .closeTab: .keys(character: "w", keyCode: 13, modifiers: .command)
        case .reopenTab: .keys(character: "t", keyCode: 17, modifiers: [.command, .shift])
        case .nextTab: .keys(character: nil, keyCode: 48, modifiers: .control)
        case .previousTab: .keys(character: nil, keyCode: 48, modifiers: [.control, .shift])
        case .navigateBack: .keys(character: "[", keyCode: 33, modifiers: .command)
        case .navigateForward: .keys(character: "]", keyCode: 30, modifiers: .command)
        case .missionControl: .dock("com.apple.expose.awake")
        case .appWindows: .dock("com.apple.expose.front.awake")
        case .showDesktop: .dock("com.apple.showdesktop.awake")
        case .spotlight: .keys(character: nil, keyCode: 49, modifiers: .command)
        case .screenshot: .keys(character: nil, keyCode: 21, modifiers: [.command, .shift])
        case .lockScreen: .keys(character: "q", keyCode: 12, modifiers: [.control, .command])
        case .desktopLeft: .keys(character: nil, keyCode: 123, modifiers: .control)
        case .desktopRight: .keys(character: nil, keyCode: 124, modifiers: .control)
        case .playPause: .media(16)
        case .nextTrack: .media(17)
        case .previousTrack: .media(18)
        case .volumeUp: .media(0)
        case .volumeDown: .media(1)
        case .mute: .media(7)
        }
    }
}

nonisolated enum ButtonAction: Codable, Hashable, Sendable {
    case original
    case disabled
    case click(MouseClick)
    case shortcut(KeyCombo)
    case preset(Preset)
    case text(String)
    case app(path: String)
}
