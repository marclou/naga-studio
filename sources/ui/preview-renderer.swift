import AppKit
import SwiftUI

/// `NagaStudio --render-preview <dir>` renders the UI to PNGs without opening a window.
enum PreviewRenderer {
    static func render(to directory: URL) {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let model = AppModel(isPreview: true)
        model.isTrusted = true
        model.isEngineRunning = true
        model.device = DeviceStatus(isConnected: true, name: "Naga V3 Pro", transport: "Bluetooth Low Energy", batteryLevel: 100)
        model.assign(.preset(.copy), to: .side1)
        model.assign(.preset(.paste), to: .side2)
        model.assign(.preset(.missionControl), to: .side4)
        model.assign(.click(.back), to: .side7)
        model.assign(.preset(.playPause), to: .side10)
        model.assign(.preset(.navigateBack), to: .tiltLeft)
        model.assign(.preset(.navigateForward), to: .tiltRight)
        model.pressedButtons = [.side5]
        model.lastSignal = InputSignal(input: .key(23), button: .side5, kind: .down)
        model.selectedButton = .side4

        let window = { WindowMain().environment(model).frame(width: 1280, height: 820) }
        write(window(), to: directory.appendingPathComponent("window-side.png"))

        model.stage = .top
        model.selectedButton = .tiltLeft
        model.pressedButtons = [.rightClick]
        write(window(), to: directory.appendingPathComponent("window-top.png"))

        model.isTrusted = false
        model.isEngineRunning = false
        write(window(), to: directory.appendingPathComponent("window-permission.png"))

        write(IconApp(), to: directory.appendingPathComponent("icon-1024.png"), scale: 1)
    }

    private static func write(_ view: some View, to url: URL, scale: CGFloat = 2) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
