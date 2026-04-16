import AppKit
import Carbon.HIToolbox

/// 全局快捷键管理器，使用 CGEventTap 实现真正的全局拦截
@MainActor
final class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()

    @Published private(set) var isAccessibilityGranted: Bool = false

    // nonisolated(unsafe): 只在主线程创建/销毁，EventTap 回调中只读（重新启用 tap）
    nonisolated(unsafe) private var eventTap: CFMachPort?
    nonisolated(unsafe) private var runLoopSource: CFRunLoopSource?

    /// 快捷键触发时的回调（主线程调用）
    var onHotKeyTriggered: (() -> Void)?

    // MARK: - 配置缓存（供 nonisolated 的 EventTap 回调直接读取，避免跨线程 sync 死锁）
    // 这些属性只在主线程写，EventTap 回调线程只读
    // nonisolated(unsafe): 我们保证主线程写、EventTap 线程只读的访问模式是安全的
    private let cacheLock = NSLock()
    nonisolated(unsafe) private var cachedKeyCode: Int = 49
    nonisolated(unsafe) private var cachedModifiers: UInt64 = CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue
    nonisolated(unsafe) private var cachedEnabled: Bool = true

    private init() {
        _ = checkAccessibilityPermission()
        updateCache()
    }

    // MARK: - 缓存更新（主线程调用）

    func updateCache() {
        cacheLock.lock()
        cachedKeyCode = ThemeManager.shared.globalHotKeyCode
        cachedModifiers = ThemeManager.shared.globalHotKeyModifiers
        cachedEnabled = ThemeManager.shared.globalHotKeyEnabled
        cacheLock.unlock()
    }

    // MARK: - Accessibility Permission

    @discardableResult
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        isAccessibilityGranted = granted
        return granted
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        // 打开系统设置后，短时间轮询一次授权状态，避免 UI 长时间停留旧值
        for delay in [0.8, 1.6, 2.8, 4.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                _ = self?.checkAccessibilityPermission()
            }
        }
    }

    // MARK: - Event Tap Management

    func start() {
        guard eventTap == nil else { return }
        guard checkAccessibilityPermission() else {
            print("[HotKeyManager] No accessibility permission, cannot start event tap")
            return
        }

        updateCache()

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            print("[HotKeyManager] Failed to create event tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[HotKeyManager] Event tap started")
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        print("[HotKeyManager] Event tap stopped")
    }

    func restart() {
        stop()
        start()
    }

    // MARK: - Event Handling

    /// nonisolated：在系统 EventTap 线程上执行，只读取缓存字段，不访问主线程数据
    private nonisolated func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // tap 被系统禁用时重新启用
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        // 直接读缓存，不碰主线程
        cacheLock.lock()
        let enabled = cachedEnabled
        let keyCodeExpected = cachedKeyCode
        let modifiersExpected = cachedModifiers
        cacheLock.unlock()

        guard enabled, keyCodeExpected >= 0 else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if keyCode == keyCodeExpected && matchModifiers(flags, expected: modifiersExpected) {
            Task { @MainActor in
                self.onHotKeyTriggered?()
            }
            // 返回 nil 消费此事件，阻止其他应用收到
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    /// 只比较 Control / Option / Shift / Command 四个修饰键
    private nonisolated func matchModifiers(_ actual: CGEventFlags, expected: UInt64) -> Bool {
        let relevantMask: UInt64 =
            CGEventFlags.maskControl.rawValue |
            CGEventFlags.maskAlternate.rawValue |
            CGEventFlags.maskShift.rawValue |
            CGEventFlags.maskCommand.rawValue

        return (actual.rawValue & relevantMask) == (expected & relevantMask)
    }

    // MARK: - Key Display Helpers

    static func displayString(keyCode: Int, modifiers: UInt64) -> String {
        guard keyCode >= 0 else { return "未设置" }

        var parts: [String] = []
        if modifiers & CGEventFlags.maskControl.rawValue != 0 { parts.append("⌃") }
        if modifiers & CGEventFlags.maskAlternate.rawValue != 0 { parts.append("⌥") }
        if modifiers & CGEventFlags.maskShift.rawValue != 0 { parts.append("⇧") }
        if modifiers & CGEventFlags.maskCommand.rawValue != 0 { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))

        return parts.joined()
    }

    static func keyCodeToString(_ keyCode: Int) -> String {
        switch keyCode {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        default: return "Key\(keyCode)"
        }
    }
}
