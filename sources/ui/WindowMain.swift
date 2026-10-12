import SwiftUI

struct WindowMain: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        ZStack {
            BackdropStage()
            VStack(spacing: 0) {
                BarHeader()
                HStack(spacing: 0) {
                    StageMain()
                    PanelInspector()
                }
                BarFooter()
            }
            if !model.isTrusted || !model.isEngineRunning {
                Color.black.opacity(0.62)
                CardPermission()
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: model.isEngineRunning)
        .onAppear(perform: appear)
        .onDisappear(perform: disappear)
    }

    private func appear() {
        guard !model.isPreview else { return }
        model.openMainWindow = { openWindow(id: AppModel.mainWindowID) }
        if AppLaunch.isLoginItem, !AppLaunch.hasHandledLoginLaunch {
            AppLaunch.hasHandledLoginLaunch = true
            Task { dismissWindow(id: AppModel.mainWindowID) }
            return
        }
        model.isWindowVisible = true
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    private func disappear() {
        guard !model.isPreview else { return }
        model.isWindowVisible = false
        NSApp.setActivationPolicy(.accessory)
    }
}

struct StageMain: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                SegmentedRazer(options: StageView.allCases, selection: $model.stage, title: \.title)
                Spacer()
                HintPress()
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)

            ZStack {
                switch model.stage {
                case .side:
                    VStack(spacing: 24) {
                        RenderNagaSide()
                            .frame(maxWidth: 740)
                            .padding(.horizontal, 36)
                        GridKeymap()
                            .frame(maxWidth: 860)
                            .padding(.horizontal, 28)
                    }
                    .transition(transition)
                case .top:
                    StageTop()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .transition(transition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 22)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: model.stage)
        }
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97))
    }
}

struct HintPress: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let isLearning = model.learningButton != nil
        Label(isLearning ? "Press the button you want to detect" : "Press a button on your mouse to select it",
              systemImage: isLearning ? "scope" : "hand.point.up.left")
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(isLearning ? Theme.amber : Theme.textTertiary)
    }
}

struct BackdropStage: View {
    var body: some View {
        ZStack {
            Theme.ink
            RadialGradient(colors: [Theme.green.opacity(0.11), .clear], center: UnitPoint(x: 0.36, y: 0.42), startRadius: 0, endRadius: 560)
            Canvas { context, size in
                var dots = Path()
                let spacing: CGFloat = 22
                for x in stride(from: spacing / 2, to: size.width, by: spacing) {
                    for y in stride(from: spacing / 2, to: size.height, by: spacing) {
                        dots.addEllipse(in: CGRect(x: x, y: y, width: 1.3, height: 1.3))
                    }
                }
                context.fill(dots, with: .color(.white.opacity(0.06)))
            }
            .mask(RadialGradient(colors: [.white, .clear], center: UnitPoint(x: 0.36, y: 0.45), startRadius: 80, endRadius: 640))
        }
    }
}
