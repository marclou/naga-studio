import CoreText
import SwiftUI

enum Theme {
    static let green = Color(red: 0.267, green: 0.839, blue: 0.173)
    static let greenLight = Color(red: 0.66, green: 1.0, blue: 0.56)
    static let ink = Color(red: 0.016, green: 0.020, blue: 0.018)
    static let panel = Color(red: 0.043, green: 0.051, blue: 0.047)
    static let raised = Color(red: 0.072, green: 0.084, blue: 0.078)
    static let hairline = Color.white.opacity(0.075)
    static let textPrimary = Color(red: 0.93, green: 0.95, blue: 0.93)
    static let textSecondary = Color(red: 0.60, green: 0.65, blue: 0.62)
    static let textTertiary = Color(red: 0.40, green: 0.44, blue: 0.42)
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.28)

    enum Weight {
        case regular, medium, semibold, bold
    }

    static func display(_ size: CGFloat, _ weight: Weight = .semibold) -> Font {
        let name = switch weight {
        case .regular: "ChakraPetch-Regular"
        case .medium: "ChakraPetch-Medium"
        case .semibold: "ChakraPetch-SemiBold"
        case .bold: "ChakraPetch-Bold"
        }
        return .custom(name, size: size)
    }

    static func registerFonts() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "fonts"), !urls.isEmpty else { return }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }
}

/// Razer-style rectangle with two 45° cut corners.
nonisolated struct ChamferedRectangle: InsettableShape {
    var cut: CGFloat = 10
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let frame = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let size = min(cut, frame.width / 2, frame.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: frame.minX + size, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - size))
        path.addLine(to: CGPoint(x: frame.maxX - size, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY + size))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> ChamferedRectangle {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

extension View {
    func neonGlow(_ color: Color = Theme.green, radius: CGFloat = 8, isOn: Bool = true) -> some View {
        shadow(color: color.opacity(isOn ? 0.75 : 0), radius: radius)
            .shadow(color: color.opacity(isOn ? 0.35 : 0), radius: radius * 2.4)
    }

    func eyebrow() -> some View {
        font(Theme.display(11, .medium))
            .tracking(0.6)
            .foregroundStyle(Theme.textTertiary)
    }

    func chamferedCard(cut: CGFloat = 10, fill: Color = Theme.raised, stroke: Color = Theme.hairline, lineWidth: CGFloat = 1) -> some View {
        background(ChamferedRectangle(cut: cut).fill(fill))
            .overlay(ChamferedRectangle(cut: cut).strokeBorder(stroke, lineWidth: lineWidth))
    }
}
