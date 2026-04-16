import SwiftUI
import AppKit
import Carbon.HIToolbox

/// 快捷键录制视图组件
struct HotKeyRecorderView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var isRecording = false
    @State private var localMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 4) {
                    if isRecording {
                        Text("按下快捷键...")
                            .foregroundStyle(.orange)
                    } else {
                        Text(currentDisplayString)
                    }
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(minWidth: 100)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.orange.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.orange : Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if theme.globalHotKeyCode >= 0 {
                Button {
                    clearHotKey()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除快捷键")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var currentDisplayString: String {
        HotKeyManager.displayString(
            keyCode: theme.globalHotKeyCode,
            modifiers: theme.globalHotKeyModifiers
        )
    }

    private func startRecording() {
        isRecording = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = Int(event.keyCode)

        // 忽略单独的修饰键
        let modifierOnlyKeys: Set<Int> = [
            kVK_Shift, kVK_RightShift,
            kVK_Control, kVK_RightControl,
            kVK_Option, kVK_RightOption,
            kVK_Command, kVK_RightCommand,
            kVK_CapsLock, kVK_Function
        ]

        if modifierOnlyKeys.contains(keyCode) { return }

        // ESC 键取消录制，不保存
        if keyCode == kVK_Escape {
            stopRecording()
            return
        }

        // 获取修饰键
        var modifiers: UInt64 = 0
        if event.modifierFlags.contains(.control) { modifiers |= CGEventFlags.maskControl.rawValue }
        if event.modifierFlags.contains(.option)  { modifiers |= CGEventFlags.maskAlternate.rawValue }
        if event.modifierFlags.contains(.shift)   { modifiers |= CGEventFlags.maskShift.rawValue }
        if event.modifierFlags.contains(.command) { modifiers |= CGEventFlags.maskCommand.rawValue }

        // 必须包含至少一个修饰键，防止普通字母被误录
        if modifiers == 0 { return }

        // 先停止录制，再保存配置
        stopRecording()

        theme.globalHotKeyCode = keyCode
        theme.globalHotKeyModifiers = modifiers

        // 先更新缓存，再异步 restart（避免在 LocalMonitor 回调上下文中同步操作 RunLoop）
        HotKeyManager.shared.updateCache()
        DispatchQueue.main.async {
            HotKeyManager.shared.restart()
        }
    }

    private func clearHotKey() {
        theme.globalHotKeyCode = -1
        theme.globalHotKeyModifiers = 0
        HotKeyManager.shared.updateCache()
        DispatchQueue.main.async {
            HotKeyManager.shared.restart()
        }
    }
}
