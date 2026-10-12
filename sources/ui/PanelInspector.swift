import SwiftUI

struct PanelInspector: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let button = model.selectedButton

        VStack(alignment: .leading, spacing: 0) {
            header(button)
            Rectangle().fill(Theme.hairline).frame(height: 1)
            if model.learningButton == button {
                CardDetecting(button: button)
                    .padding(16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if model.canRemap(button) {
                CardAssignment(button: button)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                library(button)
            } else {
                CardHardware(button: button)
                    .padding(16)
                Spacer()
            }
        }
        .frame(width: 352)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.panel.opacity(0.94))
        .overlay(alignment: .leading) { Rectangle().fill(Theme.hairline).frame(width: 1) }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: model.learningButton)
    }

    private func header(_ button: NagaButton) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(button.isSide ? "Side plate" : "Top and edges").eyebrow()
            Text(button.title)
                .font(Theme.display(28, .bold))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.opacity)
            HStack(spacing: 8) {
                Label(model.input(for: button)?.label ?? "No input detected", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                if model.settings.learnedInputs[button] != nil {
                    Button("Forget") { model.forgetLearnedInput(for: button) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                if !button.isLocked {
                    Button("Detect") { model.startLearning(button) }
                        .buttonStyle(ButtonRazerStyle(kind: .ghost))
                        .help("Press the physical button to bind it")
                }
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private func library(_ button: NagaButton) -> some View {
        let content = VStack(alignment: .leading, spacing: 20) {
            SectionActions(title: "Basics", actions: [.original, .disabled], button: button)
            SectionActions(title: "Mouse", actions: MouseClick.allCases.map(ButtonAction.click), button: button)
            ForEach(ActionCategory.allCases, id: \.self) { category in
                SectionActions(title: category.title,
                               actions: Preset.allCases.filter { $0.category == category }.map(ButtonAction.preset),
                               button: button)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Custom").eyebrow()
                RecorderShortcut(button: button)
                FieldSnippet(button: button)
                ButtonChooseApp(button: button)
            }
        }
        .padding(16)

        if model.isPreview {
            content.frame(minHeight: 0, maxHeight: .infinity, alignment: .top).clipped()
        } else {
            ScrollView { content }.scrollIndicators(.never)
        }
    }
}

struct CardAssignment: View {
    @Environment(AppModel.self) private var model
    let button: NagaButton

    var body: some View {
        let display = model.display(for: button)
        HStack(spacing: 14) {
            Image(systemName: display.symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(display.isRemapped ? Theme.green : Theme.textSecondary)
                .frame(width: 46, height: 46)
                .chamferedCard(cut: 9, fill: Theme.green.opacity(display.isRemapped ? 0.14 : 0.04),
                               stroke: Theme.green.opacity(display.isRemapped ? 0.5 : 0.15))
                .neonGlow(radius: 8, isOn: display.isRemapped)
            VStack(alignment: .leading, spacing: 3) {
                Text("Current action").eyebrow()
                Text(display.title)
                    .font(Theme.display(18, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let detail = display.detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(Theme.textTertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if display.isRemapped {
                Button { model.assign(.original, to: button) } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .chamferedCard(cut: 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .help("Back to default")
            }
        }
        .padding(14)
        .chamferedCard(cut: 14, fill: Theme.raised, stroke: Theme.green.opacity(display.isRemapped ? 0.35 : 0.1))
    }
}

struct CardHardware: View {
    @Environment(AppModel.self) private var model
    let button: NagaButton

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(button.isLocked ? "Locked" : "Handled by the mouse",
                  systemImage: button.isLocked ? "lock.fill" : "memorychip")
                .font(Theme.display(15, .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(button.hardwareNote ?? "")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !button.isLocked {
                Button("Detect input") { model.startLearning(button) }
                    .buttonStyle(ButtonRazerStyle(kind: .primary))
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chamferedCard(cut: 14)
    }
}

struct CardDetecting: View {
    @Environment(AppModel.self) private var model
    let button: NagaButton

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .phaseAnimator([0.4, 1.0]) { content, phase in content.opacity(phase) } animation: { _ in .easeInOut(duration: 0.5) }
            VStack(alignment: .leading, spacing: 2) {
                Text("Listening").font(Theme.display(14, .semibold)).foregroundStyle(Theme.textPrimary)
                Text("Press \(button.title.lowercased()) on your mouse.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Button("Cancel") { model.learningButton = nil }
                .buttonStyle(ButtonRazerStyle(kind: .ghost))
        }
        .padding(14)
        .chamferedCard(cut: 12, fill: Theme.amber.opacity(0.08), stroke: Theme.amber.opacity(0.5))
    }
}

struct SectionActions: View {
    let title: String
    let actions: [ButtonAction]
    let button: NagaButton

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrow()
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(actions, id: \.self) { action in
                    ChipAction(action: action, button: button)
                }
            }
        }
    }
}

struct ChipAction: View {
    @Environment(AppModel.self) private var model
    let action: ButtonAction
    let button: NagaButton

    var body: some View {
        let isCurrent = model.action(for: button) == action
        let display = action == .original
            ? ActionDisplay(title: "Default", detail: nil, symbol: "arrow.uturn.backward", isRemapped: false)
            : action.display(for: button)

        Button { model.assign(action, to: button) } label: {
            HStack(spacing: 8) {
                Image(systemName: display.symbol)
                    .font(.system(size: 11.5, weight: .semibold))
                    .frame(width: 16)
                Text(display.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isCurrent ? Theme.green : Theme.textPrimary.opacity(0.88))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .chamferedCard(cut: 7,
                           fill: isCurrent ? Theme.green.opacity(0.14) : Theme.raised,
                           stroke: isCurrent ? Theme.green.opacity(0.8) : Theme.hairline)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(display.detail.map { "\(display.title) · \($0)" } ?? display.title)
    }
}
