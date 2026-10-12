import SwiftUI

struct CardPermission: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let needsInputMonitoring = model.isTrusted && !model.isEngineRunning
        let paneName = needsInputMonitoring ? "Input Monitoring" : "Accessibility"

        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: needsInputMonitoring ? "keyboard.badge.eye" : "hand.raised.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.green)
                    .frame(width: 54, height: 54)
                    .chamferedCard(cut: 10, fill: Theme.green.opacity(0.12), stroke: Theme.green.opacity(0.5))
                    .neonGlow(radius: 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text("One step left").eyebrow()
                    Text("Allow \(paneName.lowercased()) access")
                        .font(Theme.display(25, .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            Text("macOS asks for this before any app can read and remap input. Naga Studio only changes events that come from your Naga. Your keyboard and trackpad pass through as they are.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                step(1, "Open Privacy & Security, then \(paneName).")
                step(2, "Turn on Naga Studio.")
                step(3, "Come back here. The app picks it up by itself.")
            }
            HStack(spacing: 10) {
                Button("Open settings") {
                    if needsInputMonitoring {
                        SystemAccess.requestInputMonitoring()
                        SystemAccess.openInputMonitoringSettings()
                    } else {
                        SystemAccess.openAccessibilitySettings()
                    }
                }
                .buttonStyle(ButtonRazerStyle(kind: .primary))
                Button("Check again") { model.startEngineIfPossible() }
                    .buttonStyle(ButtonRazerStyle(kind: .ghost))
            }
        }
        .padding(30)
        .frame(width: 520)
        .chamferedCard(cut: 18, fill: Theme.panel, stroke: Theme.green.opacity(0.45))
        .shadow(color: .black.opacity(0.65), radius: 40, y: 20)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(Theme.display(13, .bold))
                .foregroundStyle(Theme.green)
                .frame(width: 24, height: 24)
                .chamferedCard(cut: 5, fill: Theme.green.opacity(0.1), stroke: Theme.green.opacity(0.4))
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
