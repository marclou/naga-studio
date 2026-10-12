import AppKit
import Observation

/// The menu bar item, built with AppKit so it keeps its own identity and can re-attach after display changes.
final class StatusBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(model: AppModel) {
        self.model = model
        super.init()
        item.autosaveName = "NagaStudioBattery"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        updateButton()
        trackDevice()
        NotificationCenter.default.addObserver(self, selector: #selector(screensDidChange),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func updateButton() {
        guard let button = item.button else { return }
        let device = model.device
        let image = NSImage(systemSymbolName: device.isConnected ? "computermouse.fill" : "computermouse", accessibilityDescription: "Naga Studio")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let level = device.isConnected ? device.batteryLevel : nil
        button.title = level.map { " \($0)%" } ?? ""
        button.appearsDisabled = !device.isConnected
        button.toolTip = device.isConnected ? nil : "\(device.name) not connected"
    }

    private func trackDevice() {
        withObservationTracking {
            _ = model.device
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateButton()
                self?.trackDevice()
            }
        }
    }

    @objc private func screensDidChange() {
        item.isVisible = false
        item.isVisible = true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let device = model.device
        menu.addItem(label(device.isConnected ? "\(device.name) connected" : "\(device.name) not connected"))
        if device.isConnected, let level = device.batteryLevel { menu.addItem(label("Battery \(level)%")) }
        menu.addItem(.separator())

        menu.addItem(command("Remapping", isOn: model.settings.isRemappingEnabled) { $0.settings.isRemappingEnabled.toggle() })
        menu.addItem(submenu("Scroll direction", ScrollDirection.allCases.map { direction in
            command(direction.title, isOn: model.settings.scrollDirection == direction) { $0.settings.scrollDirection = direction }
        }))
        menu.addItem(submenu("Profile", model.settings.profiles.map { profile in
            command(profile.name, isOn: profile.id == model.activeProfile.id) { $0.activateProfile(profile.id) }
        }))
        menu.addItem(.separator())
        menu.addItem(command("Open Naga Studio…") { $0.showMainWindow() })
        menu.addItem(command("Quit Naga Studio", key: "q") { _ in NSApp.terminate(nil) })
    }

    private func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        items.forEach(menu.addItem)
        parent.submenu = menu
        return parent
    }

    private func command(_ title: String, isOn: Bool = false, key: String = "", perform: @escaping (AppModel) -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(run(_:)), keyEquivalent: key)
        item.target = self
        item.state = isOn ? .on : .off
        item.representedObject = perform
        return item
    }

    @objc private func run(_ sender: NSMenuItem) {
        (sender.representedObject as? (AppModel) -> Void)?(model)
    }
}
