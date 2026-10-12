import SwiftUI

/// A fixed drawing canvas that scales uniformly into whatever rect the view gets.
nonisolated struct DesignSpace: Sendable {
    let size: CGSize

    func scale(in rect: CGRect) -> CGFloat {
        min(rect.width / size.width, rect.height / size.height)
    }

    func transform(in rect: CGRect) -> CGAffineTransform {
        let scale = scale(in: rect)
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                 tx: rect.midX - size.width * scale / 2,
                                 ty: rect.midY - size.height * scale / 2)
    }

    func point(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        point.applying(transform(in: rect))
    }
}

nonisolated struct DesignShape: Shape {
    let space: DesignSpace
    let path: Path

    func path(in rect: CGRect) -> Path {
        path.applying(space.transform(in: rect))
    }
}

nonisolated extension Path {
    static func capsule(center: CGPoint, size: CGSize, cornerRadius: CGFloat, rotation degrees: CGFloat = 0) -> Path {
        let frame = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        let transform = CGAffineTransform(rotationAngle: degrees * .pi / 180)
            .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        return Path(roundedRect: frame, cornerRadius: cornerRadius, style: .continuous).applying(transform)
    }

    static func curve(_ start: CGPoint, _ segments: [(CGPoint, CGPoint, CGPoint)], closed: Bool = false) -> Path {
        var path = Path()
        path.move(to: start)
        for (control1, control2, end) in segments {
            path.addCurve(to: end, control1: control1, control2: control2)
        }
        if closed { path.closeSubpath() }
        return path
    }
}

private nonisolated func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

/// Left side of the mouse, front pointing left. The 12-button plate is the hero.
nonisolated enum SideGeometry {
    static let space = DesignSpace(size: CGSize(width: 600, height: 300))

    static let body = Path.curve(p(48, 252), [
        (p(36, 248), p(28, 238), p(27, 220)),
        (p(26, 205), p(23, 190), p(20, 176)),
        (p(19, 170), p(22, 166), p(28, 163)),
        (p(60, 146), p(90, 124), p(120, 110)),
        (p(190, 80), p(290, 62), p(394, 62)),
        (p(480, 62), p(540, 100), p(568, 150)),
        (p(586, 182), p(588, 226), p(568, 248)),
        (p(560, 255), p(552, 256), p(540, 256)),
        (p(380, 256), p(220, 256), p(66, 256)),
        (p(58, 256), p(52, 255), p(48, 252)),
    ], closed: true)

    static let leftButton = Path.curve(p(28, 163), [
        (p(60, 146), p(90, 124), p(120, 110)),
        (p(190, 80), p(250, 68), p(312, 64)),
        (p(296, 70), p(280, 76), p(262, 84)),
        (p(180, 112), p(90, 150), p(26, 172)),
        (p(24, 168), p(25, 165), p(28, 163)),
    ], closed: true)

    static let seam = Path.curve(p(26, 172), [(p(90, 150), p(180, 112), p(262, 84)), (p(280, 76), p(296, 70), p(312, 64))])

    static let highlight = Path.capsule(center: p(300, 75), size: CGSize(width: 270, height: 14), cornerRadius: 7, rotation: -8)

    static let palmLight = body

    static let plate = Path.capsule(center: p(319.5, 162.5), size: CGSize(width: 202, height: 160), cornerRadius: 26, rotation: -6.3)

    static let ledge = Path.curve(p(206, 240), [(p(270, 250), p(362, 250), p(428, 236))])

    static let wheel = Path.capsule(center: p(142, 100), size: CGSize(width: 46, height: 12), cornerRadius: 6, rotation: -22)
    static let dpiUp = Path.capsule(center: p(104, 147), size: CGSize(width: 32, height: 9), cornerRadius: 4.5, rotation: -24)
    static let dpiDown = Path.capsule(center: p(157, 126), size: CGSize(width: 32, height: 9), cornerRadius: 4.5, rotation: -22)

    static let feet: Path = {
        var path = Path()
        path.addRoundedRect(in: CGRect(x: 90, y: 255, width: 72, height: 4.5), cornerSize: CGSize(width: 2, height: 2))
        path.addRoundedRect(in: CGRect(x: 438, y: 255, width: 90, height: 4.5), cornerSize: CGSize(width: 2, height: 2))
        return path
    }()

    static let floorShadow = Path(ellipseIn: CGRect(x: 46, y: 242, width: 524, height: 32))

    static let keySize = CGSize(width: 40, height: 38)
    static let keyRotation: CGFloat = 0

    /// Key centers indexed by side number - 1: columns run front to back, numbers count upward,
    /// and each column sits a little higher than the one in front of it.
    static let keyCenters: [CGPoint] = (0..<12).map { index in
        let column = CGFloat(index / 3)
        let row = CGFloat(2 - index % 3)
        return p(252 + column * 45, 128 + row * 42 - column * 5)
    }

    static let keys: [Path] = keyCenters.map { .capsule(center: $0, size: keySize, cornerRadius: 8) }
}

/// Top view, front pointing up.
nonisolated enum TopGeometry {
    static let space = DesignSpace(size: CGSize(width: 380, height: 560))

    static let body = Path.curve(p(186, 24), [
        (p(150, 16), p(104, 18), p(76, 30)),
        (p(50, 42), p(40, 70), p(38, 104)),
        (p(36, 140), p(36, 168), p(32, 196)),
        (p(18, 236), p(16, 318), p(34, 352)),
        (p(48, 376), p(74, 384), p(74, 420)),
        (p(74, 474), p(104, 540), p(190, 550)),
        (p(276, 540), p(318, 500), p(322, 456)),
        (p(326, 410), p(330, 372), p(338, 330)),
        (p(348, 280), p(364, 240), p(360, 196)),
        (p(356, 140), p(346, 84), p(316, 48)),
        (p(292, 22), p(240, 16), p(186, 24)),
    ], closed: true)

    static let leftButton = Path.curve(p(180, 26), [
        (p(148, 18), p(104, 20), p(76, 31)),
        (p(50, 43), p(40, 70), p(38, 104)),
        (p(36, 150), p(36, 200), p(38, 238)),
        (p(90, 230), p(140, 226), p(171, 226)),
        (p(171, 160), p(171, 100), p(171, 44)),
        (p(171, 34), p(175, 28), p(180, 26)),
    ], closed: true)

    static let rightButton = Path.curve(p(192, 26), [
        (p(230, 18), p(286, 20), p(314, 46)),
        (p(344, 80), p(356, 140), p(358, 196)),
        (p(360, 222), p(356, 240), p(350, 256)),
        (p(300, 236), p(246, 228), p(201, 226)),
        (p(201, 160), p(201, 100), p(201, 44)),
        (p(201, 34), p(197, 28), p(192, 26)),
    ], closed: true)

    static let wheelWell = Path(roundedRect: CGRect(x: 172, y: 52, width: 28, height: 118), cornerRadius: 13, style: .continuous)
    static let wheel = Path(roundedRect: CGRect(x: 177, y: 62, width: 18, height: 90), cornerRadius: 8, style: .continuous)

    static let wheelRidges: Path = {
        var path = Path()
        for index in 0..<11 {
            let y = 68 + CGFloat(index) * 7.8
            path.move(to: p(179, y))
            path.addLine(to: p(193, y))
        }
        return path
    }()

    static let tiltLeft = Path.curve(p(168, 96), [(p(166, 100), p(166, 104), p(166, 106)), (p(166, 108), p(166, 112), p(168, 116))])
    static let tiltRight = Path.curve(p(204, 96), [(p(206, 100), p(206, 104), p(206, 106)), (p(206, 108), p(206, 112), p(204, 116))])
    static let tiltLeftHit = Path(roundedRect: CGRect(x: 158, y: 70, width: 14, height: 76), cornerRadius: 6)
    static let tiltRightHit = Path(roundedRect: CGRect(x: 200, y: 70, width: 14, height: 76), cornerRadius: 6)

    static let scrollMode = Path(roundedRect: CGRect(x: 176, y: 180, width: 20, height: 17), cornerRadius: 5, style: .continuous)
    static let aiPrompt = Path(roundedRect: CGRect(x: 176, y: 204, width: 20, height: 17), cornerRadius: 5, style: .continuous)

    static let dpiUp = Path.capsule(center: p(37, 86), size: CGSize(width: 12, height: 38), cornerRadius: 6, rotation: 4)
    static let dpiDown = Path.capsule(center: p(35.5, 131), size: CGSize(width: 12, height: 38), cornerRadius: 6, rotation: 2)

    static let ringFinger = Path.capsule(center: p(357, 206), size: CGSize(width: 13, height: 112), cornerRadius: 6.5, rotation: -3)

    static let sideKeys: [Path] = [
        .capsule(center: p(28, 248), size: CGSize(width: 18, height: 22), cornerRadius: 5, rotation: 10),
        .capsule(center: p(25, 274), size: CGSize(width: 18, height: 22), cornerRadius: 5, rotation: 4),
        .capsule(center: p(25, 300), size: CGSize(width: 18, height: 22), cornerRadius: 5, rotation: -2),
        .capsule(center: p(28, 326), size: CGSize(width: 18, height: 22), cornerRadius: 5, rotation: -8),
    ]

    static let emblem: Path = {
        var path = Path()
        let center = p(186, 436)
        for (index, radius) in [20.0, 11.0].enumerated() {
            let points = (0..<6).map { step -> CGPoint in
                let angle = CGFloat(step) * .pi / 3 + .pi / 6
                return p(center.x + radius * cos(angle), center.y + radius * sin(angle))
            }
            path.addLines(points)
            path.closeSubpath()
            if index == 1 { path.addEllipse(in: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)) }
        }
        return path
    }()

    static let floorShadow = Path(ellipseIn: CGRect(x: 30, y: 60, width: 330, height: 500))

    /// Where callout lines meet the mouse.
    static func anchor(for button: NagaButton) -> CGPoint {
        switch button {
        case .dpiUp: p(37, 86)
        case .dpiDown: p(35.5, 131)
        case .leftClick: p(112, 168)
        case .tiltLeft: p(166, 106)
        case .wheelClick: p(186, 90)
        case .tiltRight: p(206, 106)
        case .rightClick: p(276, 132)
        case .scrollMode: p(186, 188.5)
        case .aiPrompt: p(186, 212.5)
        case .ringFinger: p(357, 214)
        default: p(28, 290)
        }
    }
}
