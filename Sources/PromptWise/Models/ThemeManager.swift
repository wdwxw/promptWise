import SwiftUI

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

    static let dismissDelayOptions: [Double] = [1, 2, 3, 5, 8, 10]
    static let itemCountOptions: [Int] = [5, 10, 15, 20, 30]

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appThemeMode") ?? "dark"
        self.mode = ThemeMode(rawValue: saved) ?? .dark
        self.quickAccessEnabled = UserDefaults.standard.object(forKey: "quickAccessEnabled") as? Bool ?? true
        let savedDelay = UserDefaults.standard.object(forKey: "quickAccessDismissDelay") as? Double
        self.quickAccessDismissDelay = savedDelay ?? 3.0
        let savedCount = UserDefaults.standard.object(forKey: "quickAccessItemCount") as? Int
        self.quickAccessItemCount = savedCount ?? 10
        if let idString = UserDefaults.standard.string(forKey: "quickAccessCategoryId") {
            self.quickAccessCategoryId = UUID(uuidString: idString)
        } else {
            self.quickAccessCategoryId = nil
        }
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

    // MARK: - Text Tertiary (#555555 / #aaaaaa)

    var textTertiary: Color {
        mode == .dark
            ? Color(nsColor: NSColor(red: 0.333, green: 0.333, blue: 0.333, alpha: 1))
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
}
