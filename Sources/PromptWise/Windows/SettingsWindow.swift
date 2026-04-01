import AppKit
import SwiftUI

final class SettingsWindow: NSWindow {
    init(contentView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "PromptWise 偏好设置"
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.hidesOnDeactivate = false
        self.center()

        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
    }

    func showAndActivate() {
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
