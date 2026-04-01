import AppKit
import SwiftUI

final class MainPanelWindow: NSPanel {
    init(contentView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 520),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.animationBehavior = .utilityWindow
        self.minSize = NSSize(width: 320, height: 400)

        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func showNear(window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let iconFrame = window.frame
        let panelSize = self.frame.size
        let screenFrame = screen.visibleFrame

        var x = iconFrame.minX - panelSize.width - 12
        if x < screenFrame.minX {
            x = iconFrame.maxX + 12
        }

        var y = iconFrame.midY - panelSize.height / 2
        y = max(screenFrame.minY, min(y, screenFrame.maxY - panelSize.height))

        self.setFrameOrigin(NSPoint(x: x, y: y))
        self.makeKeyAndOrderFront(nil)
    }

    func toggle(near window: NSWindow) {
        if isVisible {
            orderOut(nil)
        } else {
            showNear(window: window)
        }
    }
}
