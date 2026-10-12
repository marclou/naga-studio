import SwiftUI

struct ToggleRazer: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                ChamferedRectangle(cut: 6)
                    .fill(isOn ? Theme.green : Color.white.opacity(0.07))
                    .overlay(ChamferedRectangle(cut: 6).strokeBorder(isOn ? Theme.greenLight.opacity(0.5) : Theme.hairline))
                    .frame(width: 42, height: 22)
                ChamferedRectangle(cut: 4)
                    .fill(isOn ? Theme.ink : Theme.textSecondary)
                    .frame(width: 16, height: 16)
                    .padding(3)
            }
            .neonGlow(radius: 6, isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct SegmentedRazer<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(Theme.display(13, .semibold))
                        .foregroundStyle(isSelected ? Theme.ink : Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 26)
                        .background {
                            if isSelected {
                                ChamferedRectangle(cut: 6)
                                    .fill(Theme.green)
                                    .neonGlow(radius: 5)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .chamferedCard(cut: 8)
    }
}

struct ButtonRazerStyle: ButtonStyle {
    enum Kind {
        case primary, ghost
    }

    var kind = Kind.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(13, .semibold))
            .padding(.horizontal, 14)
            .frame(height: 32)
            .foregroundStyle(kind == .primary ? Theme.ink : Theme.green)
            .chamferedCard(cut: 7,
                           fill: kind == .primary ? Theme.green : Theme.green.opacity(0.08),
                           stroke: Theme.green.opacity(kind == .primary ? 0 : 0.45))
            .neonGlow(radius: 6, isOn: kind == .primary && !configuration.isPressed)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
