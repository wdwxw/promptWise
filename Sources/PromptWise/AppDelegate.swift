import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingIconWindow: FloatingIconWindow!
    private var mainPanelWindow: MainPanelWindow!
    private var settingsWindow: SettingsWindow!
    private var quickAccessWindow: QuickAccessWindow!
    private var quickAccessDismissWork: DispatchWorkItem?
    private var iconHovered = false
    private var qaHovered = false
    private var isIconDragging = false
    private let store = PromptStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for utility-style app
        NSApp.setActivationPolicy(.accessory)

        setupFloatingIcon()
        setupMainPanel()
        setupQuickAccess()
        setupSettingsWindow()
        setupMenuBarItem()

        NotificationCenter.default.addObserver(
            forName: .openSettings, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                self.openPreferences()
            }
        }

        floatingIconWindow.makeKeyAndOrderFront(nil)
    }

    private func setupFloatingIcon() {
        floatingIconWindow = FloatingIconWindow()
        floatingIconWindow.onClick = { [weak self] in
            self?.toggleMainPanel()
        }
        floatingIconWindow.onHoverChanged = { [weak self] hovering in
            self?.iconHovered = hovering
            self?.updateQuickAccessVisibility()
        }
        floatingIconWindow.onDragStarted = { [weak self] in
            self?.isIconDragging = true
            self?.mainPanelWindow.orderOut(nil)
            self?.quickAccessWindow.orderOut(nil)
            self?.quickAccessDismissWork?.cancel()
        }
        floatingIconWindow.onDragEnded = { [weak self] in
            self?.isIconDragging = false
        }
        floatingIconWindow.onPositionChanged = { [weak self] in
            guard let self, quickAccessWindow.isVisible else { return }
            quickAccessWindow.repositionBelow(window: floatingIconWindow)
        }
    }

    private func setupMainPanel() {
        let panelView = MainPanelView(store: store, onClose: { [weak self] in
            self?.mainPanelWindow.orderOut(nil)
        })
        .environmentObject(ThemeManager.shared)
        mainPanelWindow = MainPanelWindow(contentView: panelView)
    }

    private func setupQuickAccess() {
        let qaView = QuickAccessView(
            store: store,
            onHoverChanged: { [weak self] hovering in
                self?.qaHovered = hovering
                self?.updateQuickAccessVisibility()
            }
        )
        .environmentObject(ThemeManager.shared)
        quickAccessWindow = QuickAccessWindow(contentView: qaView)
    }

    private func setupSettingsWindow() {
        let settingsView = SettingsView(store: store)
            .environmentObject(ThemeManager.shared)
        settingsWindow = SettingsWindow(contentView: settingsView)
    }

    private var statusItem: NSStatusItem?

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "PromptWise") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "PW"
            }
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "显示/隐藏面板", action: #selector(toggleMainPanel), keyEquivalent: "p")
        menu.addItem(withTitle: "显示/隐藏悬浮图标", action: #selector(toggleFloatingIcon), keyEquivalent: "f")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "偏好设置...", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出 PromptWise", action: #selector(quitApp), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    @objc private func menuBarItemClicked() {
        toggleMainPanel()
    }

    @objc private func toggleMainPanel() {
        quickAccessWindow.orderOut(nil)
        quickAccessDismissWork?.cancel()
        mainPanelWindow.toggle(near: floatingIconWindow)
    }

    // MARK: - Quick Access

    private func updateQuickAccessVisibility() {
        guard ThemeManager.shared.quickAccessEnabled, !isIconDragging else {
            quickAccessWindow.orderOut(nil)
            quickAccessDismissWork?.cancel()
            return
        }

        if iconHovered || qaHovered {
            quickAccessDismissWork?.cancel()
            quickAccessDismissWork = nil

            if !quickAccessWindow.isVisible && !store.prompts.isEmpty {
                quickAccessWindow.showBelow(window: floatingIconWindow)
            }
        } else {
            startQuickAccessDismissTimer()
        }
    }

    private func startQuickAccessDismissTimer() {
        quickAccessDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.quickAccessWindow.orderOut(nil)
        }
        quickAccessDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + ThemeManager.shared.quickAccessDismissDelay, execute: work)
    }

    @objc private func toggleFloatingIcon() {
        if floatingIconWindow.isVisible {
            floatingIconWindow.orderOut(nil)
        } else {
            floatingIconWindow.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openPreferences() {
        settingsWindow.showAndActivate()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("com.promptwise.openSettings")
}
