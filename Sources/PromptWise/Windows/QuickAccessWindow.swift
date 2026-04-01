import AppKit
import SwiftUI

final class QuickAccessWindow: NSPanel {
    init(contentView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
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

        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func repositionBelow(window: NSWindow) {
        guard let hostView = self.contentView else { return }
        let contentSize = hostView.fittingSize
        guard contentSize.height > 0 else { return }

        let iconFrame = window.frame
        var x = iconFrame.midX - contentSize.width / 2
        var y = iconFrame.minY - contentSize.height - 4

        if let screen = window.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            if y < screenFrame.minY { y = iconFrame.maxY + 4 }
            x = max(screenFrame.minX, min(x, screenFrame.maxX - contentSize.width))
        }

        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func showBelow(window: NSWindow) {
        guard let hostView = self.contentView else { return }
        let contentSize = hostView.fittingSize
        guard contentSize.height > 0 else { return }

        self.setContentSize(contentSize)

        let iconFrame = window.frame
        var x = iconFrame.midX - contentSize.width / 2
        var y = iconFrame.minY - contentSize.height - 4

        if let screen = window.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            if y < screenFrame.minY {
                y = iconFrame.maxY + 4
            }
            x = max(screenFrame.minX, min(x, screenFrame.maxX - contentSize.width))
        }

        self.setFrameOrigin(NSPoint(x: x, y: y))
        self.orderFront(nil)
    }
}
