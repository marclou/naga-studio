import AppKit
import SwiftUI

Theme.registerFonts()

if let index = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.indices.contains(index + 1) {
    PreviewRenderer.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
    exit(0)
}

NagaStudioApp.main()

struct NagaStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    var body: some Scene {
        Window("Naga Studio", id: AppModel.mainWindowID) {
            WindowMain()
                .environment(model)
                .frame(minWidth: 1120, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 820)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
