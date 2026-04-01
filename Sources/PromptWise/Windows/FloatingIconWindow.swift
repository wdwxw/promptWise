import AppKit
import SwiftUI

final class FloatingIconWindow: NSPanel {
    var onClick: (() -> Void)?
    private var isDragging = false
    private var dragStartLocation: NSPoint = .zero
    private var windowStartOrigin: NSPoint = .zero

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 56, height: 56),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.animationBehavior = .utilityWindow

        let hostingView = NSHostingView(rootView: FloatingIconContent())
        hostingView.frame = NSRect(x: 0, y: 0, width: 56, height: 56)
        self.contentView = hostingView

        positionAtDefaultLocation()
    }

    private func positionAtDefaultLocation() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - 80
        let y = screenFrame.midY
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    override var canBecomeKey: Bool { true }
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
            }
            if isDragging {
                self.setFrameOrigin(NSPoint(
                    x: windowStartOrigin.x + dx,
                    y: windowStartOrigin.y + dy
                ))
            }
        case .leftMouseUp:
            if !isDragging {
                onClick?()
            }
            isDragging = false
        default:
            super.sendEvent(event)
        }
    }
}

// MARK: - SwiftUI Visual Content

private struct FloatingIconContent: View {
    @State private var isHovered = false

    var body: some View {
        ZStack {
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

            Image(systemName: "text.bubble.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 50, height: 50)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .frame(width: 56, height: 56)
    }
}
