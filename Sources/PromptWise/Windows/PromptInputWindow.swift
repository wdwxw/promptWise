import AppKit
import SwiftUI

final class PromptInputWindow: NSPanel {
    
    init(contentView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = false
        
        self.contentView = NSHostingView(rootView: contentView)
    }
    
    /// 显示在屏幕中心
    func showCentered() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Toggle 显示/隐藏
    func toggle() {
        if isVisible {
            orderOut(nil)
        } else {
            showCentered()
        }
    }
    
    /// ESC 键关闭
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}
