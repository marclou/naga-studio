import SwiftUI

/// The 12 side buttons laid out like the physical plate: columns front to back, numbers counting upward.
struct GridKeymap: View {
    private let rows: [[Int]] = [[3, 6, 9, 12], [2, 5, 8, 11], [1, 4, 7, 10]]

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { number in
                        TileKey(button: NagaButton.side[number - 1])
                    }
                }
            }
        }
    }
}

struct TileKey: View {
    @Environment(AppModel.self) private var model
    let button: NagaButton

    var body: some View {
        let display = model.display(for: button)
        let isSelected = model.selectedButton == button
        let isPressed = model.pressedButtons.contains(button)

        HStack(spacing: 10) {
            Text("\(button.sideNumber ?? 0)")
                .font(Theme.display(16, .bold))
                .foregroundStyle(isPressed ? Theme.ink : Theme.green)
                .frame(width: 30, height: 30)
                .chamferedCard(cut: 6, fill: isPressed ? Theme.green : Theme.green.opacity(0.1), stroke: Theme.green.opacity(0.35))
            VStack(alignment: .leading, spacing: 1) {
                Text(display.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(display.isRemapped ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                Text(display.detail ?? "")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: display.symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(display.isRemapped ? Theme.green : Theme.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .chamferedCard(cut: 10,
                       fill: isPressed ? Theme.green.opacity(0.18) : Theme.panel.opacity(0.9),
                       stroke: isSelected ? Theme.green : Theme.hairline,
                       lineWidth: isSelected ? 1.4 : 1)
        .neonGlow(radius: 7, isOn: isSelected)
        .contentShape(ChamferedRectangle(cut: 10))
        .onTapGesture { model.select(button) }
        .animation(.easeOut(duration: 0.14), value: isPressed)
    }
}
