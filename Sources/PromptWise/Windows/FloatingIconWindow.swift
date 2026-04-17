import AppKit
import SwiftUI

final class FloatingIconWindow: NSPanel {
    private enum Layout {
        static let windowSize: CGFloat = 96
        static let centerIconSize: CGFloat = 50
        static let orbitDiameter: CGFloat = 80
        static let orbitRadius: CGFloat = orbitDiameter / 2
        static let clusterAngle: CGFloat = 136
        static let gapAngle: CGFloat = 30
        static let themeIconSize: CGFloat = 18
        static let themeTapRadius: CGFloat = 12
    }
    
    private enum OrbitTapTarget {
        case lightMode
        case darkMode
        case promptInput
    }

    var onClick: (() -> Void)?
    var onPromptInputClick: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    var onPositionChanged: (() -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?
    private var isDragging = false
    private var dragStartLocation: NSPoint = .zero
    private var windowStartOrigin: NSPoint = .zero

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Layout.windowSize, height: Layout.windowSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.animationBehavior = .utilityWindow

        let hostingView = NSHostingView(rootView: FloatingIconContent(
            onHoverChanged: { [weak self] hovering in
                self?.onHoverChanged?(hovering)
            }
        ).environmentObject(ThemeManager.shared))
        hostingView.frame = NSRect(x: 0, y: 0, width: Layout.windowSize, height: Layout.windowSize)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        self.contentView = hostingView

        positionAtDefaultLocation()
    }

    private func positionAtDefaultLocation() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - Layout.windowSize - 24
        let y = screenFrame.midY
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// 将悬浮图标移动到指定位置（居中于该点）
    func positionAt(_ point: NSPoint) {
        let x = point.x - Layout.windowSize / 2
        let y = point.y - Layout.windowSize / 2

        // 确保不超出屏幕边界
        var finalX = x
        var finalY = y

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            finalX = max(screenFrame.minX, min(finalX, screenFrame.maxX - Layout.windowSize))
            finalY = max(screenFrame.minY, min(finalY, screenFrame.maxY - Layout.windowSize))
        }

        self.setFrameOrigin(NSPoint(x: finalX, y: finalY))
    }

    /// 将悬浮图标移动到当前鼠标位置
    func positionAtMouseLocation() {
        let mouseLocation = NSEvent.mouseLocation
        positionAt(mouseLocation)
    }

    private func orbitPointYDown(angle: CGFloat) -> CGPoint {
        let radians = angle * .pi / 180
        let center = Layout.windowSize / 2
        let x = center + sin(radians) * Layout.orbitRadius
        let y = center - cos(radians) * Layout.orbitRadius
        return CGPoint(x: x, y: y)
    }

    private func hitTestOrbitTarget(at pointInWindow: NSPoint) -> OrbitTapTarget? {
        let yDown = Layout.windowSize - pointInWindow.y
        let sunAngle = Layout.clusterAngle - (Layout.gapAngle / 2)
        let moonAngle = Layout.clusterAngle + (Layout.gapAngle / 2)
        let pencilAngle = Layout.clusterAngle + 180
        let targets: [(OrbitTapTarget, CGPoint)] = [
            (.lightMode, orbitPointYDown(angle: sunAngle)),
            (.darkMode, orbitPointYDown(angle: moonAngle)),
            (.promptInput, orbitPointYDown(angle: pencilAngle))
        ]

        for (target, center) in targets {
            let dx = pointInWindow.x - center.x
            let dy = yDown - center.y
            if sqrt(dx * dx + dy * dy) <= Layout.themeTapRadius {
                return target
            }
        }
        return nil
    }

    // 返回 false 防止点击/拖动悬浮图标时抢夺外部应用的 Key Window 焦点
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // Intercept ALL mouse events at the window level before they reach SwiftUI
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            isDragging = false
            dragStartLocation = NSEvent.mouseLocation
            windowStartOrigin = self.frame.origin
        case .leftMouseDragged:
            let current = NSEvent.mouseLocation
            let dx = current.x - dragStartLocation.x
            let dy = current.y - dragStartLocation.y
            if !isDragging && (abs(dx) > 2 || abs(dy) > 2) {
                isDragging = true
                onDragStarted?()
            }
            if isDragging {
                self.setFrameOrigin(NSPoint(
                    x: windowStartOrigin.x + dx,
                    y: windowStartOrigin.y + dy
                ))
                onPositionChanged?()
            }
        case .leftMouseUp:
            if !isDragging {
                if let target = hitTestOrbitTarget(at: event.locationInWindow) {
                    switch target {
                    case .lightMode:
                        ThemeManager.shared.mode = .light
                    case .darkMode:
                        ThemeManager.shared.mode = .dark
                    case .promptInput:
                        onPromptInputClick?()
                    }
                    break
                }
                onClick?()
            } else {
                onDragEnded?()
            }
            isDragging = false
        default:
            super.sendEvent(event)
        }
    }
}

// MARK: - SwiftUI Visual Content

private struct FloatingIconContent: View {
    private enum Layout {
        static let windowSize: CGFloat = 96
        static let centerIconSize: CGFloat = 50
        static let orbitDiameter: CGFloat = 80
        static let orbitRadius: CGFloat = orbitDiameter / 2
        static let clusterAngle: CGFloat = 136
        static let gapAngle: CGFloat = 30
        static let themeIconSize: CGFloat = 18
    }

    var onHoverChanged: ((Bool) -> Void)?
    @State private var isHovered = false
    @EnvironmentObject private var theme: ThemeManager

    private func orbitPoint(angle: CGFloat) -> CGPoint {
        let radians = angle * .pi / 180
        let center = Layout.windowSize / 2
        let x = center + sin(radians) * Layout.orbitRadius
        let y = center - cos(radians) * Layout.orbitRadius
        return CGPoint(x: x, y: y)
    }

    private var sunPoint: CGPoint {
        orbitPoint(angle: Layout.clusterAngle - (Layout.gapAngle / 2))
    }

    private var moonPoint: CGPoint {
        orbitPoint(angle: Layout.clusterAngle + (Layout.gapAngle / 2))
    }
    
    private var pencilPoint: CGPoint {
        orbitPoint(angle: Layout.clusterAngle + 180)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.001))
                .frame(width: Layout.windowSize, height: Layout.windowSize)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .systemIndigo),
                            Color(nsColor: .systemPurple)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: isHovered ? 8 : 4, y: 2)
                .frame(width: Layout.centerIconSize, height: Layout.centerIconSize)
                .position(x: Layout.windowSize / 2, y: Layout.windowSize / 2)

            Image(systemName: "text.bubble.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .position(x: Layout.windowSize / 2, y: Layout.windowSize / 2)

            themeNode(
                symbol: "sun.max.fill",
                textSymbol: nil,
                mode: .light
            )
            .position(sunPoint)

            themeNode(
                symbol: nil,
                textSymbol: "☾",
                mode: .dark
            )
            .position(moonPoint)

            promptInputNode()
                .position(pencilPoint)
        }
        .frame(width: Layout.windowSize, height: Layout.windowSize)
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            onHoverChanged?(hovering)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    @ViewBuilder
    private func themeNode(symbol: String?, textSymbol: String?, mode: ThemeMode) -> some View {
        let isActive = theme.mode == mode
        let sunFill = Color(red: 0.96, green: 0.62, blue: 0.04)
        let moonFill = Color(red: 0.15, green: 0.39, blue: 0.92)
        let activeGlow = mode == .light
            ? Color(red: 0.98, green: 0.79, blue: 0.26)
            : Color(red: 0.45, green: 0.67, blue: 0.98)

        ZStack {
            Circle()
                .fill(
                    mode == .light
                        ? sunFill.opacity(isActive ? 1.0 : 0.30)
                        : moonFill.opacity(isActive ? 1.0 : 0.30)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0.88 : 0.30), lineWidth: isActive ? 1.1 : 0.9)
                )
                .shadow(
                    color: isActive ? activeGlow.opacity(0.62) : .clear,
                    radius: isActive ? 8 : 0
                )
                .shadow(
                    color: isActive ? activeGlow.opacity(0.42) : .clear,
                    radius: isActive ? 3 : 0
                )

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(
                        isActive
                            ? Color(red: 1.0, green: 0.98, blue: 0.90)
                            : Color(red: 1.0, green: 0.95, blue: 0.64)
                    )
            }

            if let textSymbol {
                Text(textSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        isActive
                            ? Color(red: 0.97, green: 0.99, blue: 1.0)
                            : Color(red: 0.76, green: 0.88, blue: 1.0)
                    )
            }
        }
        .frame(width: Layout.themeIconSize, height: Layout.themeIconSize)
    }
    
    private func promptInputNode() -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.24, green: 0.24, blue: 0.28).opacity(0.92))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.36), lineWidth: 0.9)
                )
                .shadow(color: .black.opacity(0.22), radius: 3)

            VStack(spacing: 0.8) {
                Image(systemName: "pencil")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(red: 0.98, green: 0.88, blue: 0.44))
                    .rotationEffect(.degrees(-20))
                    .offset(x: 0.4, y: 0.2)

                RoundedRectangle(cornerRadius: 0.6)
                    .fill(Color(red: 0.98, green: 0.88, blue: 0.44).opacity(0.95))
                    .frame(width: 8.5, height: 1.1)
                    .offset(y: 0.3)
            }
        }
        .frame(width: Layout.themeIconSize, height: Layout.themeIconSize)
    }
}
