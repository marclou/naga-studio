import SwiftUI

/// Rendered once to build AppIcon.icns.
struct IconApp: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.07, green: 0.085, blue: 0.075), Color(red: 0.01, green: 0.013, blue: 0.011)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 186, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                                      lineWidth: 4)
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.45), radius: 28, y: 14)

            Circle()
                .fill(Theme.green.opacity(0.38))
                .frame(width: 520, height: 520)
                .blur(radius: 110)

            Grid(horizontalSpacing: 24, verticalSpacing: 24) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<4, id: \.self) { column in
                            key(isHot: row == 1 && column == 2)
                        }
                    }
                }
            }
            .rotationEffect(.degrees(-8))
        }
        .frame(width: 1024, height: 1024)
    }

    private func key(isHot: Bool) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(isHot
                ? AnyShapeStyle(Theme.green)
                : AnyShapeStyle(LinearGradient(colors: [Color(white: 0.17), Color(white: 0.06)], startPoint: .top, endPoint: .bottom)))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isHot ? Theme.greenLight : Theme.green.opacity(0.8), lineWidth: 5)
            )
            .frame(width: 134, height: 112)
            .shadow(color: Theme.green.opacity(isHot ? 0.95 : 0.45), radius: isHot ? 40 : 14)
    }
}
