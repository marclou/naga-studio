import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RecorderShortcut: View {
    @Environment(AppModel.self) private var model
    let button: NagaButton
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        let isCurrent = if case .shortcut = model.action(for: button) { true } else { false }

        Button { isRecording ? stop() : start() } label: {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
                if isRecording {
                    Text("Esc cancels").font(.system(size: 10.5)).foregroundStyle(Theme.textTertiary)
                }
            }
            .foregroundStyle(isRecording || isCurrent ? Theme.green : Theme.textPrimary.opacity(0.88))
            .padding(.horizontal, 10)
            .frame(height: 36)
            .chamferedCard(cut: 7,
                           fill: isRecording ? Theme.green.opacity(0.1) : Theme.raised,
                           stroke: isRecording || isCurrent ? Theme.green.opacity(0.8) : Theme.hairline)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: button) { stop() }
        .onDisappear { stop() }
    }

    private var label: String {
        if isRecording { return "Press a shortcut…" }
        if case .shortcut(let combo) = model.action(for: button) { return "Shortcut \(combo.label)" }
        return "Record a shortcut"
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                stop()
                return nil
            }
            model.assign(.shortcut(KeyCombo(keyCode: event.keyCode, modifiers: ModifierSet(event.modifierFlags))), to: button)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}

struct FieldSnippet: View {
    @Environment(AppModel.self) private var model
    let button: NagaButton
    @State private var draft = ""

    var body: some View {
        let isCurrent = if case .text = model.action(for: button) { true } else { false }

        HStack(spacing: 8) {
            Image(systemName: "text.cursor")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isCurrent ? Theme.green : Theme.textPrimary.opacity(0.88))
                .frame(width: 16)
            TextField("Text to type", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit(apply)
            Button("Use", action: apply)
                .buttonStyle(.plain)
                .font(Theme.display(12, .semibold))
                .foregroundStyle(draft.isEmpty ? Theme.textTertiary : Theme.green)
                .disabled(draft.isEmpty)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .chamferedCard(cut: 7, fill: Theme.raised, stroke: isCurrent ? Theme.green.opacity(0.8) : Theme.hairline)
        .onAppear(perform: loadDraft)
        .onChange(of: button) { loadDraft() }
    }

    private func apply() {
        guard !draft.isEmpty else { return }
        model.assign(.text(draft), to: button)
    }

    private func loadDraft() {
        if case .text(let text) = model.action(for: button) { draft = text } else { draft = "" }
    }
}

struct ButtonChooseApp: View {
    @Environment(AppModel.self) private var model
    let button: NagaButton

    var body: some View {
        let currentPath: String? = if case .app(let path) = model.action(for: button) { path } else { nil }

        Button(action: chooseApp) {
            HStack(spacing: 8) {
                if let currentPath {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: currentPath))
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "app.badge")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 16)
                }
                Text(currentPath.map { "Opens \(URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent)" } ?? "Open an app…")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(currentPath == nil ? Theme.textPrimary.opacity(0.88) : Theme.green)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .chamferedCard(cut: 7, fill: Theme.raised, stroke: currentPath == nil ? Theme.hairline : Theme.green.opacity(0.8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.assign(.app(path: url.path), to: button)
    }
}
