import AppKit
import Observation

enum StageView: String, CaseIterable, Identifiable {
    case side, top

    var id: String { rawValue }
    var title: String { self == .side ? "Side" : "Top" }
}

struct ScrollPulse: Equatable {
    var isUp = true
    var count = 0
}

@Observable
final class AppModel {
    static let shared = AppModel()
    static let mainWindowID = "main"

    var settings: Settings {
        didSet {
            guard !isPreview else { return }
            settings.save()
            syncEngine()
        }
    }
    var selectedButton = NagaButton.side1
    var learningButton: NagaButton? { didSet { syncEngine() } }
    var pressedButtons: Set<NagaButton> = []
    var lastSignal: InputSignal?
    var lastSignalDate = Date.distantPast
    var scrollPulse = ScrollPulse()
    var stage = StageView.side
    var isTrusted = false
    var isEngineRunning = false
    var device = DeviceStatus() {
        didSet { if device.isConnected != oldValue.isConnected { syncEngine() } }
    }
    var opensAtLogin = false
    var isSystemNatural = true
    var isAppActive = false { didSet { syncEngine() } }
    var isWindowVisible = false { didSet { syncEngine() } }

    @ObservationIgnored let engine = EventEngine()
    @ObservationIgnored let isPreview: Bool
    @ObservationIgnored var openMainWindow: (() -> Void)?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var batteryMonitor: BatteryMonitor?

    private static let pointerButtons: Set<NagaButton> = [.leftClick, .rightClick]
    private static let didSetUpLoginItemKey = "didSetUpLoginItem"

    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        settings = isPreview ? Settings() : Settings.load()
        guard !isPreview else { return }

        isSystemNatural = SystemAccess.isNaturalScrolling
        device = DeviceMonitor.scan()
        batteryMonitor = BatteryMonitor { [weak self] level in
            guard let self, device.isConnected, level != device.batteryLevel else { return }
            device.batteryLevel = level
        }
        batteryMonitor?.refresh()
        setUpLoginItemOnFirstLaunch()
        observeSystem()
        listenToEngine()
        startPolling()
        startEngineIfPossible()
        if !isTrusted { SystemAccess.requestTrust() }
        syncEngine()
    }

    var activeProfileID: UUID {
        get { activeProfile.id }
        set { activateProfile(newValue) }
    }

    var isOpenAtLoginEnabled: Bool {
        get { opensAtLogin }
        set { setOpensAtLogin(newValue) }
    }

    // MARK: Selection and live input

    var isWindowInFront: Bool { isAppActive && isWindowVisible }

    func select(_ button: NagaButton) {
        selectedButton = button
        stage = button.isSide ? .side : .top
        if learningButton != button { learningButton = nil }
    }

    func handle(_ signal: InputSignal) {
        if signal.kind != .up {
            lastSignal = signal
            lastSignalDate = .now
        }
        switch signal.kind {
        case .scrollUp, .scrollDown:
            scrollPulse = ScrollPulse(isUp: signal.kind == .scrollUp, count: scrollPulse.count + 1)
        case .down, .tap:
            if let learningButton, let input = signal.input, input != .mouse(0) {
                learn(input, for: learningButton)
                return
            }
            guard let button = signal.button else { return }
            pressedButtons.insert(button)
            if isWindowInFront, !Self.pointerButtons.contains(button) { select(button) }
            if signal.kind == .tap {
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(220))
                    self?.pressedButtons.remove(button)
                }
            }
        case .up:
            if let button = signal.button { pressedButtons.remove(button) }
        }
    }

    // MARK: Profiles and assignments

    var activeProfile: Profile {
        get { settings.profiles.first { $0.id == settings.activeProfileID } ?? settings.profiles[0] }
        set {
            guard let index = settings.profiles.firstIndex(where: { $0.id == newValue.id }) else { return }
            settings.profiles[index] = newValue
        }
    }

    func action(for button: NagaButton) -> ButtonAction {
        activeProfile.actions[button] ?? .original
    }

    func assign(_ action: ButtonAction, to button: NagaButton) {
        guard !button.isLocked else { return }
        var profile = activeProfile
        profile.actions[button] = action == .original ? nil : action
        activeProfile = profile
    }

    func resetActiveProfile() {
        var profile = activeProfile
        profile.actions = [:]
        activeProfile = profile
    }

    func activateProfile(_ id: UUID) {
        settings.activeProfileID = id
    }

    func addProfile() {
        let profile = Profile(name: "Profile \(settings.profiles.count + 1)")
        settings.profiles.append(profile)
        settings.activeProfileID = profile.id
    }

    func duplicateActiveProfile() {
        let source = activeProfile
        let copy = Profile(name: "\(source.name) copy", actions: source.actions)
        settings.profiles.append(copy)
        settings.activeProfileID = copy.id
    }

    func renameActiveProfile(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var profile = activeProfile
        profile.name = trimmed
        activeProfile = profile
    }

    func deleteActiveProfile() {
        guard settings.profiles.count > 1 else { return }
        let id = activeProfile.id
        settings.profiles.removeAll { $0.id == id }
        settings.activeProfileID = settings.profiles.first?.id
    }

    // MARK: Inputs and detection

    func input(for button: NagaButton) -> NagaInput? {
        if let learned = settings.learnedInputs[button] { return learned }
        let claimed = Set(settings.learnedInputs.values)
        return button.defaultInputs.first { !claimed.contains($0) }
    }

    func canRemap(_ button: NagaButton) -> Bool {
        !button.isLocked && input(for: button) != nil
    }

    func startLearning(_ button: NagaButton) {
        selectedButton = button
        learningButton = button
    }

    func forgetLearnedInput(for button: NagaButton) {
        settings.learnedInputs[button] = nil
    }

    private func learn(_ input: NagaInput, for button: NagaButton) {
        var learned = settings.learnedInputs.filter { $0.value != input }
        learned[button] = button.defaultInputs.contains(input) ? nil : input
        settings.learnedInputs = learned
        learningButton = nil
    }

    // MARK: System

    func setOpensAtLogin(_ isEnabled: Bool) {
        SystemAccess.setOpensAtLogin(isEnabled)
        opensAtLogin = SystemAccess.opensAtLogin
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        openMainWindow?()
        NSApp.activate()
    }

    func startEngineIfPossible() {
        guard !isPreview else { return }
        let trusted = SystemAccess.isTrusted
        if trusted != isTrusted { isTrusted = trusted }
        guard isTrusted, !isEngineRunning else { return }
        isEngineRunning = engine.start()
    }

    func syncEngine() {
        guard !isPreview else { return }
        engine.update(makeEngineConfig())
    }

    private func makeEngineConfig() -> EngineConfig {
        var buttonsByInput: [NagaInput: NagaButton] = [:]
        for button in NagaButton.allCases {
            for input in button.defaultInputs { buttonsByInput[input] = button }
        }
        for (button, input) in settings.learnedInputs {
            buttonsByInput = buttonsByInput.filter { $0.value != button }
            buttonsByInput[input] = button
        }

        let layout = KeyboardLayout.reverseMap()
        var actions: [NagaButton: EngineAction] = [:]
        for (button, action) in activeProfile.actions where !button.isLocked {
            actions[button] = action.engineAction(using: layout)
        }

        return EngineConfig(
            isRemappingEnabled: settings.isRemappingEnabled,
            invertsScroll: isSystemNatural != (settings.scrollDirection == .natural),
            isDetecting: learningButton != nil,
            isAppFrontmost: isWindowInFront,
            isNagaConnected: device.isConnected,
            isSystemNatural: isSystemNatural,
            buttonsByInput: buttonsByInput,
            actions: actions
        )
    }

    private func setUpLoginItemOnFirstLaunch() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.didSetUpLoginItemKey) {
            defaults.set(true, forKey: Self.didSetUpLoginItemKey)
            SystemAccess.setOpensAtLogin(true)
        }
        opensAtLogin = SystemAccess.opensAtLogin
    }

    private func listenToEngine() {
        let signals = engine.signals
        Task { [weak self] in
            for await signal in signals { self?.handle(signal) }
        }
    }

    private func startPolling() {
        Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                startEngineIfPossible()
                let wasConnected = device.isConnected
                var status = DeviceMonitor.scan()
                status.batteryLevel = status.isConnected ? device.batteryLevel : nil
                if status != device { device = status }
                if status.isConnected, !wasConnected || tick % 100 == 0 { batteryMonitor?.refresh() }
                tick += 1
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func observeSystem() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isAppActive = true
                self.isSystemNatural = SystemAccess.isNaturalScrolling
                self.startEngineIfPossible()
            }
        })
        observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isAppActive = false }
        })

        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: Notification.Name("SwipeScrollDirectionDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isSystemNatural = SystemAccess.isNaturalScrolling
                self.syncEngine()
            }
        })
        observers.append(distributed.addObserver(forName: Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncEngine() }
        })
    }
}

extension ButtonAction {
    func engineAction(using layout: [String: UInt16]) -> EngineAction? {
        switch self {
        case .original: nil
        case .disabled: .swallow
        case .click(let click): .click(click)
        case .shortcut(let combo): .keys(keyCode: combo.keyCode, modifiers: combo.modifiers)
        case .text(let text): text.isEmpty ? .swallow : .text(text)
        case .app(let path): .openApp(path)
        case .preset(let preset):
            switch preset.effect {
            case let .keys(character, keyCode, modifiers): .keys(keyCode: character.flatMap { layout[$0] } ?? keyCode, modifiers: modifiers)
            case .dock(let name): .dock(name)
            case .media(let key): .media(key)
            }
        }
    }
}
