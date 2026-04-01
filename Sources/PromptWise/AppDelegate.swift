import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingIconWindow: FloatingIconWindow!
    private var mainPanelWindow: MainPanelWindow!
    private let store = PromptStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for utility-style app
        NSApp.setActivationPolicy(.accessory)

        setupFloatingIcon()
        setupMainPanel()
        setupMenuBarItem()

        floatingIconWindow.makeKeyAndOrderFront(nil)
    }

    private func setupFloatingIcon() {
        floatingIconWindow = FloatingIconWindow()
        floatingIconWindow.onClick = { [weak self] in
            self?.toggleMainPanel()
        }
    }

    private func setupMainPanel() {
        let panelView = MainPanelView(store: store, onClose: { [weak self] in
            self?.mainPanelWindow.orderOut(nil)
        })
        mainPanelWindow = MainPanelWindow(contentView: panelView)
    }

    private var statusItem: NSStatusItem?

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "PromptWise")
            button.action = #selector(menuBarItemClicked)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "显示/隐藏面板", action: #selector(toggleMainPanel), keyEquivalent: "p")
        menu.addItem(withTitle: "显示/隐藏悬浮图标", action: #selector(toggleFloatingIcon), keyEquivalent: "f")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出 PromptWise", action: #selector(quitApp), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    @objc private func menuBarItemClicked() {
        toggleMainPanel()
    }

    @objc private func toggleMainPanel() {
        mainPanelWindow.toggle(near: floatingIconWindow)
    }

    @objc private func toggleFloatingIcon() {
        if floatingIconWindow.isVisible {
            floatingIconWindow.orderOut(nil)
        } else {
            floatingIconWindow.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
