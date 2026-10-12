import CoreGraphics
import Foundation
import Synchronization

nonisolated struct EngineConfig: Sendable {
    var isRemappingEnabled = true
    var invertsScroll = false
    /// Detect is listening: every Naga press is captured for binding and does nothing else.
    var isDetecting = false
    /// Unmapped Naga keys would only type stray digits into the app's own window.
    var isAppFrontmost = false
    var isNagaConnected = false
    var isSystemNatural = true
    var buttonsByInput: [NagaInput: NagaButton] = [:]
    var actions: [NagaButton: EngineAction] = [:]

    func mappedAction(for button: NagaButton?) -> EngineAction? {
        guard isRemappingEnabled, let button else { return nil }
        return actions[button]
    }
}

nonisolated struct InputSignal: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case down, up, tap, scrollUp, scrollDown
    }

    var input: NagaInput?
    var button: NagaButton?
    var kind: Kind
    var didRunAction = false
}

/// The user-space driver: an event tap that sees every input before apps do and rewrites the Naga's.
nonisolated final class EventEngine: @unchecked Sendable {
    let signals: AsyncStream<InputSignal>

    private let continuation: AsyncStream<InputSignal>.Continuation
    private let config = Mutex(EngineConfig())
    private let resolver = DeviceResolver()
    private let performer = ActionPerformer()

    // Assigned on the main thread before the tap thread starts; read-only afterwards.
    private var tap: CFMachPort?

    // Touched only on the tap thread.
    private var activeActions: [NagaInput: EngineAction] = [:]
    private var lastTiltTime: [TiltDirection: UInt64] = [:]
    private var lastScrollSignalTime: UInt64 = 0

    private static let tiltPressGap: UInt64 = 300_000_000
    private static let scrollSignalGap: UInt64 = 40_000_000

    init() {
        (signals, continuation) = AsyncStream.makeStream(of: InputSignal.self, bufferingPolicy: .bufferingNewest(256))
    }

    var canIdentifyDevices: Bool { resolver.isAvailable }

    func update(_ newConfig: EngineConfig) {
        config.withLock { $0 = newConfig }
    }

    /// Returns false when macOS refuses the tap, which means the permission is missing.
    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [
            .keyDown, .keyUp, .scrollWheel,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
            .rightMouseDragged, .otherMouseDragged,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                return Unmanaged<EventEngine>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let thread = Thread { [self] in runTapLoop() }
        thread.name = "Naga Studio event tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        return true
    }

    private func runTapLoop() {
        guard let tap else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let passthrough = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return passthrough
        }
        guard event.getIntegerValueField(.eventSourceUserData) != ActionPerformer.syntheticMarker else { return passthrough }

        let config = config.withLock { $0 }
        guard isFromNaga(type, event, config) else {
            // Repeats and releases of a held, remapped Naga key must never leak, whatever device macOS credits them to.
            let isFollowUp = type == .keyUp || (type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
            let input = NagaInput.key(UInt16(event.getIntegerValueField(.keyboardEventKeycode)))
            guard isFollowUp, activeActions[input] != nil else { return passthrough }
            return handleKey(type, event, config) ? nil : passthrough
        }
        let shouldSwallow = switch type {
        case .keyDown, .keyUp: handleKey(type, event, config)
        case .scrollWheel: handleScroll(event, config)
        case .rightMouseDragged, .otherMouseDragged:
            activeActions[.mouse(Int(event.getIntegerValueField(.mouseEventButtonNumber)))] != nil
        default: handleMouseButton(type, event, config)
        }
        return shouldSwallow ? nil : passthrough
    }

    private func isFromNaga(_ type: CGEventType, _ event: CGEvent, _ config: EngineConfig) -> Bool {
        switch resolver.origin(of: event) {
        case .naga:
            true
        case .otherDevice:
            false
        case .unattributed(let pid):
            // Middle clicks come without their device; the built-in trackpad never sends one, so a
            // hardware middle click while the Naga is connected is the Naga's wheel.
            config.isNagaConnected
                && [CGEventType.otherMouseDown, .otherMouseUp, .otherMouseDragged].contains(type)
                && resolver.isSystemProcess(pid)
        }
    }

    private func handleKey(_ type: CGEventType, _ event: CGEvent, _ config: EngineConfig) -> Bool {
        let input = NagaInput.key(UInt16(event.getIntegerValueField(.keyboardEventKeycode)))
        let button = config.buttonsByInput[input]

        guard type == .keyDown else {
            emit(input, button, .up)
            guard let action = activeActions.removeValue(forKey: input) else { return false }
            performer.perform(action, phase: .up)
            return true
        }

        if let action = activeActions[input] {
            performer.perform(action, phase: .repeated)
            return true
        }
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return false }

        let mapped = config.isDetecting ? nil : config.mappedAction(for: button)
        emit(input, button, .down, didRunAction: mapped != nil)
        let action = config.isDetecting || config.isAppFrontmost ? mapped ?? .swallow : mapped
        guard let action else { return false }
        activeActions[input] = action
        performer.perform(action, phase: .down)
        return true
    }

    private func handleMouseButton(_ type: CGEventType, _ event: CGEvent, _ config: EngineConfig) -> Bool {
        let number = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        let input = NagaInput.mouse(number)
        let button = config.buttonsByInput[input]
        let isDown = type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown

        guard isDown else {
            emit(input, button, .up)
            guard number != 0, let action = activeActions.removeValue(forKey: input) else { return false }
            performer.perform(action, phase: .up)
            return true
        }

        let isLeftClick = number == 0
        let mapped = isLeftClick || config.isDetecting ? nil : config.mappedAction(for: button)
        emit(input, button, .down, didRunAction: mapped != nil)
        let action: EngineAction? = !isLeftClick && config.isDetecting ? .swallow : mapped
        guard let action else { return false }
        activeActions[input] = action
        performer.perform(action, phase: .down)
        return true
    }

    private func handleScroll(_ event: CGEvent, _ config: EngineConfig) -> Bool {
        let vertical = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let horizontal = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        // Natural scrolling flips deltas before the tap sees them; undo that to get the physical direction.
        let physicalSign: Double = config.isSystemNatural ? -1 : 1
        let now = DispatchTime.now().uptimeNanoseconds

        if vertical == 0, horizontal != 0 {
            let direction: TiltDirection = horizontal * physicalSign > 0 ? .left : .right
            let input = NagaInput.tilt(direction)
            let button = config.buttonsByInput[input]
            let isNewPress = now &- (lastTiltTime[direction] ?? 0) > Self.tiltPressGap
            lastTiltTime[direction] = now
            let mapped = config.isDetecting ? nil : config.mappedAction(for: button)
            if isNewPress { emit(input, button, .tap, didRunAction: mapped != nil) }
            if config.isDetecting { return true }
            if let mapped {
                if isNewPress {
                    performer.perform(mapped, phase: .down)
                    performer.perform(mapped, phase: .up)
                }
                return true
            }
        } else if vertical != 0, now &- lastScrollSignalTime > Self.scrollSignalGap {
            lastScrollSignalTime = now
            emit(nil, nil, vertical * physicalSign > 0 ? .scrollUp : .scrollDown)
        }

        if config.invertsScroll { Self.invert(event) }
        return false
    }

    private static func invert(_ event: CGEvent) {
        let delta1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let delta2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let point1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let point2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        let fixed1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixed2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        // Order matters: setting the line delta recomputes the others.
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -delta1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -delta2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -point1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -point2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixed1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixed2)
    }

    private func emit(_ input: NagaInput?, _ button: NagaButton?, _ kind: InputSignal.Kind, didRunAction: Bool = false) {
        continuation.yield(InputSignal(input: input, button: button, kind: kind, didRunAction: didRunAction))
    }
}
