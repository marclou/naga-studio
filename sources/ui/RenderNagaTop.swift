import SwiftUI

struct RenderNagaTop: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            let scale = TopGeometry.space.scale(in: rect)
            let space = TopGeometry.space
            ZStack {
                shape(TopGeometry.floorShadow).fill(Theme.green.opacity(0.2)).blur(radius: 44 * scale)
                shape(TopGeometry.body).fill(Color.black.opacity(0.85)).blur(radius: 16 * scale).offset(y: 12 * scale)

                shape(TopGeometry.body).fill(RadialGradient(
                    colors: [Color(white: 0.17), Color(white: 0.085), Color(white: 0.035)],
                    center: UnitPoint(x: 0.46, y: 0.58), startRadius: 0, endRadius: 330 * scale))
                shape(TopGeometry.body).stroke(LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.03)],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                                               lineWidth: 1.3 * scale)

                PartNaga(button: .leftClick, space: space, path: TopGeometry.leftButton, finish: .surface)
                PartNaga(button: .rightClick, space: space, path: TopGeometry.rightButton, finish: .surface)

                shape(TopGeometry.wheelWell).fill(Color.black.opacity(0.9))
                shape(TopGeometry.wheelWell).stroke(Color.white.opacity(0.07), lineWidth: scale)
                PartNaga(button: .wheelClick, space: space, path: TopGeometry.wheel, finish: .lit)
                shape(TopGeometry.wheelRidges).stroke(Color.black.opacity(0.4), lineWidth: 1.6 * scale).allowsHitTesting(false)
                PartNaga(button: .tiltLeft, space: space, path: TopGeometry.tiltLeft, finish: .chevron, hitPath: TopGeometry.tiltLeftHit)
                PartNaga(button: .tiltRight, space: space, path: TopGeometry.tiltRight, finish: .chevron, hitPath: TopGeometry.tiltRightHit)

                PartNaga(button: .scrollMode, space: space, path: TopGeometry.scrollMode)
                PartNaga(button: .aiPrompt, space: space, path: TopGeometry.aiPrompt)
                PartNaga(button: .dpiUp, space: space, path: TopGeometry.dpiUp)
                PartNaga(button: .dpiDown, space: space, path: TopGeometry.dpiDown)
                PartNaga(button: .ringFinger, space: space, path: TopGeometry.ringFinger)

                ForEach(TopGeometry.sideKeys.indices, id: \.self) { index in
                    let key = shape(TopGeometry.sideKeys[index])
                    ZStack {
                        key.fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.06)], startPoint: .leading, endPoint: .trailing))
                        key.stroke(Theme.green.opacity(0.7), lineWidth: scale).neonGlow(radius: 3 * scale)
                    }
                    .contentShape(key)
                    .onTapGesture { model.stage = .side }
                    .help("Side plate")
                }

                shape(TopGeometry.emblem).stroke(Theme.green, style: StrokeStyle(lineWidth: 1.8 * scale, lineJoin: .round))
                    .neonGlow(radius: 6 * scale)
                    .allowsHitTesting(false)

                pulse(in: rect, scale: scale)
            }
        }
        .aspectRatio(380 / 560, contentMode: .fit)
    }

    private func shape(_ path: Path) -> DesignShape {
        DesignShape(space: TopGeometry.space, path: path)
    }

    private func pulse(in rect: CGRect, scale: CGFloat) -> some View {
        let isUp = model.scrollPulse.isUp
        let anchor = TopGeometry.space.point(CGPoint(x: 186, y: isUp ? 40 : 178), in: rect)
        return Image(systemName: isUp ? "chevron.compact.up" : "chevron.compact.down")
            .font(.system(size: 26 * scale, weight: .bold))
            .foregroundStyle(Theme.greenLight)
            .neonGlow(radius: 6)
            .keyframeAnimator(initialValue: 1.0, trigger: model.scrollPulse.count) { content, progress in
                content
                    .opacity(1 - progress)
                    .offset(y: (isUp ? -1 : 1) * progress * 22 * scale)
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(1, duration: 0.55)
            }
            .position(anchor)
            .allowsHitTesting(false)
    }
}

/// Top view with Synapse-style callouts on both sides.
struct StageTop: View {
    @Environment(AppModel.self) private var model

    /// Ordered top to bottom so no two lines cross; the tilt line enters above the DPI buttons,
    /// and the lines to the buttons behind the wheel come in between the DPI buttons and the side keys.
    private let leftButtons: [NagaButton] = [.tiltLeft, .dpiUp, .dpiDown, .leftClick, .scrollMode, .aiPrompt]
    private let rightButtons: [NagaButton] = [.wheelClick, .tiltRight, .rightClick, .ringFinger]
    private let labelWidth: CGFloat = 200
    private let labelSpacing: CGFloat = 54
    private let gap: CGFloat = 46

    var body: some View {
        GeometryReader { proxy in
            let mouseRect = mouseRect(in: proxy.size)
            let leftEdge = mouseRect.minX - gap
            let rightEdge = mouseRect.maxX + gap
            let leftSlots = slots(for: leftButtons, in: mouseRect, bounds: proxy.size)
            let rightSlots = slots(for: rightButtons, in: mouseRect, bounds: proxy.size)

            ZStack {
                RenderNagaTop()
                    .frame(width: mouseRect.width, height: mouseRect.height)
                    .position(x: mouseRect.midX, y: mouseRect.midY)

                ForEach(Array(leftButtons.enumerated()), id: \.element) { index, button in
                    CalloutLine(from: CGPoint(x: leftEdge, y: leftSlots[index]), to: anchor(button, in: mouseRect),
                                isLeft: true, isSelected: model.selectedButton == button)
                }
                ForEach(Array(rightButtons.enumerated()), id: \.element) { index, button in
                    CalloutLine(from: CGPoint(x: rightEdge, y: rightSlots[index]), to: anchor(button, in: mouseRect),
                                isLeft: false, isSelected: model.selectedButton == button)
                }

                ForEach(Array(leftButtons.enumerated()), id: \.element) { index, button in
                    CalloutLabel(button: button, isLeading: false)
                        .frame(width: labelWidth, alignment: .trailing)
                        .position(x: leftEdge - labelWidth / 2, y: leftSlots[index])
                }
                ForEach(Array(rightButtons.enumerated()), id: \.element) { index, button in
                    CalloutLabel(button: button, isLeading: true)
                        .frame(width: labelWidth, alignment: .leading)
                        .position(x: rightEdge + labelWidth / 2, y: rightSlots[index])
                }
            }
        }
    }

    private func mouseRect(in size: CGSize) -> CGRect {
        let maxWidth = max(size.width - 2 * (labelWidth + gap + 12), 160)
        let height = min(size.height, maxWidth * 560 / 380)
        let width = height * 380 / 560
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    /// Label centers as close to each anchor's height as the spacing allows, kept inside the stage.
    private func slots(for buttons: [NagaButton], in rect: CGRect, bounds: CGSize) -> [CGFloat] {
        let anchors = buttons.map { anchor($0, in: rect).y }
        var slots = anchors
        for index in slots.indices.dropFirst() {
            slots[index] = max(anchors[index], slots[index - 1] + labelSpacing)
        }
        let drift = slots.reduce(0, +) / CGFloat(slots.count) - anchors.reduce(0, +) / CGFloat(anchors.count)
        slots = slots.map { $0 - drift }
        let top: CGFloat = 30
        let bottom = bounds.height - 30
        if let first = slots.first, first < top { slots = slots.map { $0 + top - first } }
        if let last = slots.last, last > bottom { slots = slots.map { $0 - (last - bottom) } }
        return slots
    }

    private func anchor(_ button: NagaButton, in rect: CGRect) -> CGPoint {
        TopGeometry.space.point(TopGeometry.anchor(for: button), in: rect)
    }
}

struct CalloutLine: View {
    let from: CGPoint
    let to: CGPoint
    let isLeft: Bool
    let isSelected: Bool

    var body: some View {
        let elbow = CGPoint(x: from.x + (isLeft ? 20 : -20), y: from.y)
        let line = Path { path in
            path.move(to: from)
            path.addLine(to: elbow)
            path.addLine(to: to)
        }
        ZStack {
            line.stroke(Color.black.opacity(0.7), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            line.stroke(Theme.green.opacity(isSelected ? 1 : 0.55),
                        style: StrokeStyle(lineWidth: isSelected ? 1.6 : 1.1, lineCap: .round, lineJoin: .round))
                .neonGlow(radius: 4, isOn: isSelected)

            Circle()
                .fill(isSelected ? Theme.greenLight : Theme.green)
                .frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.75), lineWidth: 1.5).padding(-1.5))
                .neonGlow(radius: 4, isOn: isSelected)
                .position(to)
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

struct CalloutLabel: View {
    @Environment(AppModel.self) private var model
    let button: NagaButton
    let isLeading: Bool

    var body: some View {
        let display = model.display(for: button)
        let isSelected = model.selectedButton == button
        let isPressed = model.pressedButtons.contains(button)

        VStack(alignment: isLeading ? .leading : .trailing, spacing: 3) {
            Text(button.title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            HStack(spacing: 6) {
                if isLeading { icon(display) }
                Text(display.title)
                    .font(Theme.display(14, .semibold))
                    .foregroundStyle(display.isRemapped ? Theme.green : Theme.textPrimary)
                    .lineLimit(1)
                if !isLeading { icon(display) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .chamferedCard(cut: 8,
                       fill: isPressed ? Theme.green.opacity(0.22) : Theme.panel.opacity(0.94),
                       stroke: isSelected ? Theme.green : Theme.hairline,
                       lineWidth: isSelected ? 1.4 : 1)
        .neonGlow(radius: 7, isOn: isSelected)
        .contentShape(Rectangle())
        .onTapGesture { model.select(button) }
        .animation(.easeOut(duration: 0.15), value: isPressed)
    }

    private func icon(_ display: ActionDisplay) -> some View {
        Image(systemName: display.symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(display.isRemapped ? Theme.green : Theme.textTertiary)
    }
}
