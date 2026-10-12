import SwiftUI

struct BarFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 16) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Scroll direction")
                        .font(Theme.display(13, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Naga only. Your trackpad keeps its setting.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
                SegmentedRazer(options: ScrollDirection.allCases, selection: $model.settings.scrollDirection, title: \.title)
            }
            Spacer()
            ReadoutLive()
            Spacer()
            HStack(spacing: 10) {
                Text("Open at login")
                    .font(Theme.display(13, .medium))
                    .foregroundStyle(Theme.textSecondary)
                ToggleRazer(isOn: $model.isOpenAtLoginEnabled)
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 62)
        .background(Theme.ink.opacity(0.7))
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }
}

struct ReadoutLive: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.isEngineRunning ? Theme.green : Theme.textTertiary)
                .frame(width: 6, height: 6)
                .neonGlow(radius: 4, isOn: model.isEngineRunning)
            Text("Live")
                .font(Theme.display(11, .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.opacity)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .chamferedCard(cut: 8, fill: Theme.panel.opacity(0.8))
        .animation(.easeOut(duration: 0.15), value: model.lastSignalDate)
    }

    private var text: String {
        guard model.isEngineRunning else { return "Waiting for permission" }
        guard let signal = model.lastSignal else { return "Press a button on your mouse" }
        switch signal.kind {
        case .scrollUp: return "Wheel up"
        case .scrollDown: return "Wheel down"
        default:
            guard let button = signal.button else { return signal.input.map { "Unassigned input · \($0.label)" } ?? "Unassigned input" }
            if signal.didRunAction { return "\(button.title) → \(model.display(for: button).title)" }
            return signal.input.map { "\(button.title) · \($0.label)" } ?? button.title
        }
    }
}
