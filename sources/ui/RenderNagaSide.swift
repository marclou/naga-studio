import SwiftUI

struct RenderNagaSide: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            let scale = SideGeometry.space.scale(in: rect)
            ZStack {
                shape(SideGeometry.floorShadow).fill(Theme.green.opacity(0.32)).blur(radius: 28 * scale).offset(y: 8 * scale)
                shape(SideGeometry.floorShadow).fill(Color.black.opacity(0.9)).blur(radius: 9 * scale)

                shape(SideGeometry.body).fill(LinearGradient(
                    colors: [Color(white: 0.19), Color(white: 0.095), Color(white: 0.045), Color(white: 0.02)],
                    startPoint: UnitPoint(x: 0.5, y: 0.14), endPoint: UnitPoint(x: 0.5, y: 0.9)))
                shape(SideGeometry.leftButton).fill(LinearGradient(colors: [Color.white.opacity(0.07), .clear], startPoint: .top, endPoint: .bottom))
                shape(SideGeometry.highlight).fill(Color.white.opacity(0.13)).blur(radius: 8 * scale)
                shape(SideGeometry.body).stroke(LinearGradient(colors: [Color.white.opacity(0.32), Color.white.opacity(0.02)],
                                                              startPoint: UnitPoint(x: 0.5, y: 0.15), endPoint: UnitPoint(x: 0.5, y: 0.75)),
                                                lineWidth: 1.3 * scale)
                shape(SideGeometry.seam).stroke(Color.black.opacity(0.75), lineWidth: 2.4 * scale)
                shape(SideGeometry.seam).stroke(Color.white.opacity(0.08), lineWidth: scale).offset(y: 1.6 * scale)

                shape(SideGeometry.palmLight).fill(RadialGradient(colors: [Color.white.opacity(0.07), .clear],
                                                                   center: UnitPoint(x: 0.76, y: 0.38), startRadius: 0, endRadius: 190 * scale))
                shape(SideGeometry.plate).fill(Theme.green.opacity(0.18)).blur(radius: 22 * scale)
                shape(SideGeometry.plate).fill(LinearGradient(colors: [Color(white: 0.03), Color(white: 0.065)], startPoint: .top, endPoint: .bottom))
                shape(SideGeometry.plate).stroke(Color.black.opacity(0.8), lineWidth: 1.6 * scale)
                shape(SideGeometry.plate).stroke(Color.white.opacity(0.06), lineWidth: scale).offset(y: 1.2 * scale)
                shape(SideGeometry.ledge).stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
                shape(SideGeometry.feet).fill(Color(white: 0.24))

                ForEach(NagaButton.side) { button in
                    KeySide(button: button, rect: rect, scale: scale)
                }
                PartNaga(button: .wheelClick, space: SideGeometry.space, path: SideGeometry.wheel, finish: .lit)
                PartNaga(button: .dpiUp, space: SideGeometry.space, path: SideGeometry.dpiUp)
                PartNaga(button: .dpiDown, space: SideGeometry.space, path: SideGeometry.dpiDown)
            }
        }
        .aspectRatio(2, contentMode: .fit)
    }

    private func shape(_ path: Path) -> DesignShape {
        DesignShape(space: SideGeometry.space, path: path)
    }
}

struct KeySide: View {
    @Environment(AppModel.self) private var model
    let button: NagaButton
    let rect: CGRect
    let scale: CGFloat

    var body: some View {
        let index = (button.sideNumber ?? 1) - 1
        let shape = DesignShape(space: SideGeometry.space, path: SideGeometry.keys[index])
        let center = SideGeometry.space.point(SideGeometry.keyCenters[index], in: rect)
        let isPressed = model.pressedButtons.contains(button)
        let isSelected = model.selectedButton == button
        let isLearning = model.learningButton == button
        let isRemapped = model.action(for: button) != .original

        ZStack {
            shape.fill(Theme.green).blur(radius: 12 * scale).opacity(isPressed ? 0.95 : 0)
            shape.fill(isPressed
                ? AnyShapeStyle(Theme.green)
                : AnyShapeStyle(LinearGradient(
                    colors: isRemapped ? [Theme.green.opacity(0.34), Theme.green.opacity(0.1)] : [Color(white: 0.17), Color(white: 0.065)],
                    startPoint: .top, endPoint: .bottom)))
            shape.stroke(isSelected ? Theme.greenLight : Theme.green.opacity(isRemapped ? 0.85 : 0.4),
                         lineWidth: (isSelected ? 2 : 1) * max(scale, 0.8))
            if isSelected || isLearning {
                shape.stroke(isLearning ? Theme.amber : Theme.green, lineWidth: 4 * scale)
                    .blur(radius: 5 * scale)
                    .phaseAnimator([0.3, 1.0]) { content, phase in content.opacity(phase) } animation: { _ in
                        .easeInOut(duration: isLearning ? 0.4 : 0.9)
                    }
            }
            Text("\(index + 1)")
                .font(Theme.display(17 * scale, .bold))
                .foregroundStyle(isPressed ? Theme.ink : (isRemapped ? Theme.greenLight : Theme.green))
                .shadow(color: Theme.green.opacity(isPressed ? 0 : 0.95), radius: 5 * scale)
                .rotationEffect(.degrees(SideGeometry.keyRotation))
                .position(center)
        }
        .contentShape(shape)
        .onTapGesture { model.select(button) }
        .help("\(button.title): \(model.display(for: button).title)")
        .animation(.spring(response: 0.16, dampingFraction: 0.62), value: isPressed)
    }
}

/// One clickable part of the mouse drawing.
struct PartNaga: View {
    enum Finish {
        case surface, control, lit, chevron
    }

    @Environment(AppModel.self) private var model
    let button: NagaButton
    let space: DesignSpace
    let path: Path
    var finish = Finish.control
    var hitPath: Path?

    var body: some View {
        let shape = DesignShape(space: space, path: path)
        let isPressed = model.pressedButtons.contains(button)
        let isSelected = model.selectedButton == button
        let isLearning = model.learningButton == button

        ZStack {
            switch finish {
            case .surface:
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.075), .clear], startPoint: .top, endPoint: .center))
                shape.fill(Theme.green.opacity(isPressed ? 0.2 : (isSelected ? 0.06 : 0)))
                shape.stroke(isSelected ? Theme.green : Color.black.opacity(0.6), lineWidth: isSelected ? 1.6 : 1.5)
            case .control:
                shape.fill(Theme.green).blur(radius: 8).opacity(isPressed ? 1 : 0)
                shape.fill(isPressed
                    ? AnyShapeStyle(Theme.green)
                    : AnyShapeStyle(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.08)], startPoint: .top, endPoint: .bottom)))
                shape.stroke(isSelected ? Theme.greenLight : Theme.green.opacity(0.35), lineWidth: isSelected ? 1.6 : 1)
            case .lit:
                shape.fill(Theme.green).blur(radius: 7).opacity(isPressed ? 1 : 0.75)
                shape.fill(LinearGradient(colors: [isPressed ? Theme.greenLight : Theme.green, Theme.green.opacity(0.55)],
                                          startPoint: .top, endPoint: .bottom))
                shape.stroke(isSelected ? Color.white : Theme.greenLight.opacity(0.6), lineWidth: isSelected ? 1.6 : 0.8)
            case .chevron:
                shape.stroke(isPressed || isSelected ? Theme.greenLight : Color.white.opacity(0.3),
                             style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .neonGlow(radius: 4, isOn: isPressed || isSelected)
            }
            if isSelected || isLearning, finish != .chevron {
                shape.stroke(isLearning ? Theme.amber : Theme.green, lineWidth: 3)
                    .blur(radius: 4)
                    .phaseAnimator([0.3, 1.0]) { content, phase in content.opacity(phase) } animation: { _ in
                        .easeInOut(duration: isLearning ? 0.4 : 0.9)
                    }
            }
        }
        .contentShape(DesignShape(space: space, path: hitPath ?? path))
        .onTapGesture { model.select(button) }
        .help("\(button.title): \(model.display(for: button).title)")
        .animation(.spring(response: 0.16, dampingFraction: 0.62), value: isPressed)
    }
}
