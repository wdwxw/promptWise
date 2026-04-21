import SwiftUI
import Carbon.HIToolbox

enum ThemeMode: String, CaseIterable, Identifiable {
    case dark = "dark"
    case light = "light"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: return "深色"
        case .light: return "浅色"
        }
    }

    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}

enum DataAddPosition: String, CaseIterable, Identifiable {
    case top = "top"
    case bottom = "bottom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top: return "顶部追加"
        case .bottom: return "末尾追加"
        }
    }
}

enum QuickAccessButtonStyle: String, CaseIterable, Identifiable {
    case transparent = "transparent"
    case solid = "solid"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .transparent: return "透明"
        case .solid: return "不透明"
        }
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var mode: ThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "appThemeMode") }
    }

    @Published var quickAccessEnabled: Bool {
        didSet { UserDefaults.standard.set(quickAccessEnabled, forKey: "quickAccessEnabled") }
    }

    @Published var quickAccessDismissDelay: Double {
        didSet { UserDefaults.standard.set(quickAccessDismissDelay, forKey: "quickAccessDismissDelay") }
    }

    @Published var quickAccessItemCount: Int {
        didSet { UserDefaults.standard.set(quickAccessItemCount, forKey: "quickAccessItemCount") }
    }

    @Published var quickAccessItemsPerColumn: Int {
        didSet { UserDefaults.standard.set(quickAccessItemsPerColumn, forKey: "quickAccessItemsPerColumn") }
    }

    /// 快捷图标列表显示的分类（nil = 全部）
    @Published var quickAccessCategoryId: UUID? {
        didSet {
            if let id = quickAccessCategoryId {
                UserDefaults.standard.set(id.uuidString, forKey: "quickAccessCategoryId")
            } else {
                UserDefaults.standard.removeObject(forKey: "quickAccessCategoryId")
            }
        }
    }

    /// 快捷图标按钮风格（透明/不透明）
    @Published var quickAccessButtonStyle: QuickAccessButtonStyle {
        didSet { UserDefaults.standard.set(quickAccessButtonStyle.rawValue, forKey: "quickAccessButtonStyle") }
    }

    /// 数据新增位置（顶部或末尾）
    @Published var dataAddPosition: DataAddPosition {
        didSet { UserDefaults.standard.set(dataAddPosition.rawValue, forKey: "dataAddPosition") }
    }

    /// 全局快捷键 - keyCode（-1 表示未设置）
    @Published var globalHotKeyCode: Int {
        didSet { UserDefaults.standard.set(globalHotKeyCode, forKey: "globalHotKeyCode") }
    }

    /// 全局快捷键 - 修饰键（CGEventFlags rawValue）
    @Published var globalHotKeyModifiers: UInt64 {
        didSet { UserDefaults.standard.set(globalHotKeyModifiers, forKey: "globalHotKeyModifiers") }
    }

    /// 全局快捷键是否启用
    @Published var globalHotKeyEnabled: Bool {
        didSet { UserDefaults.standard.set(globalHotKeyEnabled, forKey: "globalHotKeyEnabled") }
    }

    // MARK: - 提示语输入快捷键配置

    /// 提示语输入快捷键 - keyCode（-1 表示未设置）
    @Published var promptInputHotKeyCode: Int {
        didSet { UserDefaults.standard.set(promptInputHotKeyCode, forKey: "promptInputHotKeyCode") }
    }

    /// 提示语输入快捷键 - 修饰键（CGEventFlags rawValue）
    @Published var promptInputHotKeyModifiers: UInt64 {
        didSet { UserDefaults.standard.set(promptInputHotKeyModifiers, forKey: "promptInputHotKeyModifiers") }
    }

    /// 提示语输入快捷键是否启用
    @Published var promptInputHotKeyEnabled: Bool {
        didSet { UserDefaults.standard.set(promptInputHotKeyEnabled, forKey: "promptInputHotKeyEnabled") }
    }

    /// 提示语输入框临时内容（草稿）
    @Published var promptInputDraft: String {
        didSet { UserDefaults.standard.set(promptInputDraft, forKey: "promptInputDraft") }
    }

    // MARK: - Debug 模式配置
    
    /// Debug 模式是否启用（控制 AI 服务日志输出）
    @Published var debugModeEnabled: Bool {
        didSet { UserDefaults.standard.set(debugModeEnabled, forKey: "debugModeEnabled") }
    }

    static let dismissDelayOptions: [Double] = [0.5, 1, 2, 3, 5, 8, 10]
    static let itemCountOptions: [Int] = [5, 10, 15, 20, 30, 50]
    static let itemsPerColumnOptions: [Int] = [5, 10]

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appThemeMode") ?? "dark"
        self.mode = ThemeMode(rawValue: saved) ?? .dark
        self.quickAccessEnabled = UserDefaults.standard.object(forKey: "quickAccessEnabled") as? Bool ?? true
        let savedDelay = UserDefaults.standard.object(forKey: "quickAccessDismissDelay") as? Double
        self.quickAccessDismissDelay = savedDelay ?? 3.0
        let savedCount = UserDefaults.standard.object(forKey: "quickAccessItemCount") as? Int
        self.quickAccessItemCount = savedCount ?? 10
        let savedItemsPerColumn = UserDefaults.standard.object(forKey: "quickAccessItemsPerColumn") as? Int
        if let savedItemsPerColumn, Self.itemsPerColumnOptions.contains(savedItemsPerColumn) {
            self.quickAccessItemsPerColumn = savedItemsPerColumn
        } else {
            self.quickAccessItemsPerColumn = 10
        }
        if let idString = UserDefaults.standard.string(forKey: "quickAccessCategoryId") {
            self.quickAccessCategoryId = UUID(uuidString: idString)
        } else {
            self.quickAccessCategoryId = nil
        }
        let savedButtonStyle = UserDefaults.standard.string(forKey: "quickAccessButtonStyle") ?? "transparent"
        self.quickAccessButtonStyle = QuickAccessButtonStyle(rawValue: savedButtonStyle) ?? .transparent
        let savedPosition = UserDefaults.standard.string(forKey: "dataAddPosition") ?? "bottom"
        self.dataAddPosition = DataAddPosition(rawValue: savedPosition) ?? .bottom

        // 全局快捷键配置（默认：Control+Option+Space）
        let savedKeyCode = UserDefaults.standard.object(forKey: "globalHotKeyCode") as? Int
        self.globalHotKeyCode = savedKeyCode ?? 49  // 49 = Space
        let savedModifiers = UserDefaults.standard.object(forKey: "globalHotKeyModifiers") as? UInt64
        // 默认修饰键：Control + Option
        self.globalHotKeyModifiers = savedModifiers ?? (CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue)
        self.globalHotKeyEnabled = UserDefaults.standard.object(forKey: "globalHotKeyEnabled") as? Bool ?? true

        // 提示语输入快捷键配置（默认：Control+Option+I）
        let savedInputKeyCode = UserDefaults.standard.object(forKey: "promptInputHotKeyCode") as? Int
        self.promptInputHotKeyCode = savedInputKeyCode ?? kVK_ANSI_I  // 34 = I
        let savedInputModifiers = UserDefaults.standard.object(forKey: "promptInputHotKeyModifiers") as? UInt64
        self.promptInputHotKeyModifiers = savedInputModifiers ?? (CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue)
        self.promptInputHotKeyEnabled = UserDefaults.standard.object(forKey: "promptInputHotKeyEnabled") as? Bool ?? true
        self.promptInputDraft = UserDefaults.standard.string(forKey: "promptInputDraft") ?? ""
        
        // Debug 模式配置（默认关闭）
        self.debugModeEnabled = UserDefaults.standard.object(forKey: "debugModeEnabled") as? Bool ?? false
    }

    // MARK: - Panel Background (#1e1e1e / #ffffff)

    var panelBg: Color {
        mode == .dark
            ? Color(nsColor: NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1))
            : Color(nsColor: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1))
    }

    // MARK: - Surface Background (#252525 / #f5f5f5)

    var surfaceBg: Color {
        mode == .dark
            ? Color(nsColor: NSColor(red: 0.145, green: 0.145, blue: 0.145, alpha: 1))
            : Color(nsColor: NSColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1))
    }

    // MARK: - Border (#2a2a2a / #e5e5e5)

    var border: Color {
        mode == .dark
            ? Color(nsColor: NSColor(red: 0.165, green: 0.165, blue: 0.165, alpha: 1))
            : Color(nsColor: NSColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1))
    }

    // MARK: - Text Primary (#bbbbbb / #444444)

    var textPrimary: Color {
        mode == .dark
            ? Color(nsColor: NSColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1))
            : Color(nsColor: NSColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1))
    }

    // MARK: - Text Secondary (#999999 / #888888)

    var textSecondary: Color {
        mode == .dark
            ? Color(nsColor: NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1))
            : Color(nsColor: NSColor(red: 0.533, green: 0.533, blue: 0.533, alpha: 1))
    }

    // MARK: - Text Tertiary (#888888 / #aaaaaa)

    var textTertiary: Color {
        mode == .dark
            ? Color(nsColor: NSColor(red: 0.533, green: 0.533, blue: 0.533, alpha: 1))
            : Color(nsColor: NSColor(red: 0.667, green: 0.667, blue: 0.667, alpha: 1))
    }

    // MARK: - Accent (#7c3aed) — shared across themes

    var accent: Color {
        Color(nsColor: NSColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1))
    }

    // MARK: - Accent Subtle (#a78bfa) — shared across themes

    var accentSubtle: Color {
        Color(nsColor: NSColor(red: 0.655, green: 0.545, blue: 0.980, alpha: 1))
    }

    // MARK: - Icon on Surface (#cccccc / #555555) — for buttons/icons on surface background

    var iconOnSurface: Color {
        mode == .dark
            ? Color(nsColor: NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1))
            : Color(nsColor: NSColor(red: 0.333, green: 0.333, blue: 0.333, alpha: 1))
    }
}
