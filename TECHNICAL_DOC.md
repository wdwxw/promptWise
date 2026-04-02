# PromptWise 技术文档

> 本文档作为项目索引，供技术人员快速定位代码和功能入口。

---

## 1. 项目概览

**技术栈:** Swift 5.9+ / SwiftUI + AppKit 混合架构 / macOS 13.0+

**项目路径:** `/usr/local/work/data1/ai/promptWise/`

**构建命令:** `swift build`

---

## 2. 目录结构

```
Sources/PromptWise/
├── PromptWiseApp.swift          # 应用入口 (@main)
├── AppDelegate.swift            # 应用代理，核心协调器
├── Models/
│   ├── Category.swift           # 分类数据模型
│   ├── Prompt.swift            # 提示语数据模型
│   ├── PromptStore.swift       # 数据存储与业务逻辑
│   └── ThemeManager.swift      # 主题系统管理
├── Views/
│   ├── MainPanelView.swift     # 主面板视图
│   ├── PromptListView.swift    # 列表/宫格视图
│   ├── PromptEditView.swift    # 新建/编辑提示语
│   ├── PromptDragSource.swift  # 拖拽功能实现
│   ├── CategoryManagerView.swift # 分类管理
│   ├── ImportView.swift        # 批量导入
│   ├── QuickAccessView.swift   # 快捷访问视图
│   └── SettingsView.swift      # 设置视图
└── Windows/
    ├── FloatingIconWindow.swift    # 悬浮图标窗口
    ├── MainPanelWindow.swift       # 主面板窗口
    ├── QuickAccessWindow.swift     # 快捷访问窗口
    └── SettingsWindow.swift       # 设置窗口
```

---

## 3. 核心文件说明

### 3.1 应用入口

| 文件 | 职责 | 关键代码 |
|------|------|---------|
| `PromptWiseApp.swift` | SwiftUI App 入口 | `@NSApplicationDelegateAdaptor(AppDelegate.self)` |
| `AppDelegate.swift` | 应用生命周期、窗口协调、事件分发 | `NSApplicationDelegate` 实现 |

**AppDelegate 核心属性:**
```swift
// 窗口实例
private var floatingIconWindow: FloatingIconWindow!
private var mainPanelWindow: MainPanelWindow!
private var settingsWindow: SettingsWindow!
private var quickAccessWindow: QuickAccessWindow!

// 状态追踪
private var iconHovered = false
private var qaHovered = false
private var isIconDragging = false

// 数据
private let store = PromptStore()
```

---

### 3.2 数据模型 (Models)

#### `Category.swift`
```swift
struct Category: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String       // 分类名称
    var icon: String       // SF Symbol 图标名
    var order: Int         // 排序顺序
}
```

#### `Prompt.swift`
```swift
struct Prompt: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String      // 标题
    var content: String   // 提示语内容 (支持 Markdown)
    var categoryId: UUID? // 所属分类
    var isStarred: Bool   // 是否标星
    var order: Int         // 排序
    var createdAt: Date
    var updatedAt: Date
}
```

#### `PromptStore.swift` ⭐ 数据中枢
```swift
@MainActor
final class PromptStore: ObservableObject {
    @Published var prompts: [Prompt] = []
    @Published var categories: [Category] = []
    private let fileURL: URL  // ~/Library/Application Support/PromptWise/data.json
}
```

**CRUD 操作:**
- `addPrompt(_:)` → 添加提示语
- `updatePrompt(_:)` → 更新提示语
- `deletePrompt(_:)` → 删除提示语
- `toggleStar(_:)` → 切换星标
- `movePrompt(_:to:)` → 调整顺序

**查询操作:**
- `prompts(for categoryId:)` → 获取分类下的提示语
- `searchPrompts(query:categoryId:)` → 搜索提示语

**导入导出:**
- `exportData() -> Data` → 导出 JSON
- `importFromText(_:)` → 从文本批量导入
- `importFromJSON(_:)` → 从 JSON 导入
- `importFromMarkdown(_:)` → 从 Markdown 导入

---

### 3.3 主题系统 (ThemeManager)

**文件:** `Models/ThemeManager.swift`

```swift
enum ThemeMode: String, CaseIterable, Identifiable {
    case dark = "dark"
    case light = "light"
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // 持久化到 UserDefaults
    @Published var mode: ThemeMode
    @Published var quickAccessEnabled: Bool
    @Published var quickAccessDismissDelay: Double  // 0.5/1/2/3/5/8/10 秒
    @Published var quickAccessItemCount: Int       // 5/10/15/20/30/50 条
    @Published var quickAccessCategoryId: UUID?
}
```

**颜色定义:**

| 颜色用途 | 深色模式 | 浅色模式 |
|---------|---------|---------|
| `panelBg` 面板背景 | #1e1e1e | #ffffff |
| `surfaceBg` 表面背景 | #252525 | #f5f5f5 |
| `border` 边框 | #2a2a2a | #e5e5e5 |
| `textPrimary` 主文字 | #bbbbbb | #444444 |
| `textSecondary` 次文字 | #999999 | #888888 |
| `textTertiary` 三级文字 | #555555 | #aaaaaa |
| `accent` 强调色 | #7c3aed | #7c3aed |
| `accentSubtle` 柔和强调 | #a78bfa | #a78bfa |

**快捷访问相关配置:**

| 配置项 | 可选值 | 默认值 |
|-------|-------|-------|
| 显示条数 | 5, 10, 15, 20, 30, 50 | 10 |
| 自动收起延迟 | 0.5, 1, 2, 3, 5, 8, 10 秒 | 3.0 |

---

## 4. 视图 (Views)

### 4.1 主面板 `MainPanelView.swift`
**职责:** 主界面容器，包含标题栏、分类栏、搜索栏、提示语列表

**关键状态:**
```swift
@State private var searchText = ""
@State private var selectedCategoryId: UUID?
@State private var viewMode: ViewMode = .list  // .list 或 .grid
@State private var showingAddPrompt = false
@State private var editingPrompt: Prompt?
```

**入口:** `AppDelegate.setupMainPanel()` → `MainPanelWindow`

---

### 4.2 列表/宫格视图 `PromptListView.swift`

**组件:**
- `PromptRowView` - 列表模式行视图（支持拖拽重排序）
- `PromptGridItemView` - 宫格模式卡片视图
- `PromptDropDelegate` - 拖拽放下处理

**特性:**
- 列表/宫格切换
- 拖拽重排序
- 悬停预览
- 点击复制到剪贴板

**入口:** `MainPanelView` 内部使用

---

### 4.3 编辑视图 `PromptEditView.swift`
**职责:** 新建/编辑提示语表单

```swift
@State private var title: String = ""
@State private var content: String = ""    // 支持 Markdown
@State private var categoryId: UUID?
@State private var showPreview = false     // 预览开关
```

**入口:** `MainPanelView.showingAddPrompt` / `MainPanelView.editingPrompt`

---

### 4.4 分类管理 `CategoryManagerView.swift`
**职责:** 分类的增删改查和排序

**可用图标:** folder, star, bookmark, tag, laptopcomputer, pencil, text.bubble, globe, brain.head.profile, lightbulb, doc.text, terminal 等

**入口:** `MainPanelView` → 菜单 "管理分类"

---

### 4.5 导入视图 `ImportView.swift`
**职责:** 批量导入提示语

**支持格式:**
1. **JSON**: `[{"title":"", "content":""}]`
2. **Markdown**: `## 标题\n内容...`

**入口:** `MainPanelView` → 菜单 "导入"

---

### 4.6 快捷访问视图 `QuickAccessView.swift`
**职责:** 悬浮图标悬停时显示的快速访问面板

**快捷按钮样式:**
- 深色模式: `Color.black.opacity(0.65)` 背景 + 白色文字
- 浅色模式: `Color.white.opacity(0.65)` 背景 + 深色文字
- 悬停时: 紫色半透明背景 + 白色文字

**入口:** `AppDelegate.setupQuickAccess()` → `QuickAccessWindow`

---

### 4.7 设置视图 `SettingsView.swift`
**职责:** 应用设置界面

**配置项:**
1. 主题切换 (深色/浅色)
2. 快捷图标设置:
   - 悬停展开开关
   - 显示条数
   - 自动收起延迟
   - 显示分类筛选

**入口:** `AppDelegate.openPreferences()` → `SettingsWindow`

---

## 5. 窗口 (Windows)

### 5.1 悬浮图标窗口 `FloatingIconWindow.swift`
```swift
final class FloatingIconWindow: NSPanel {
    // 56x56 像素圆形图标
    // 渐变紫色 (systemIndigo -> systemPurple)

    var onClick: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    var onPositionChanged: (() -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?
}
```

**特性:**
- `NSWindow.Level.statusBar` 级别（始终置顶）
- 拦截鼠标事件实现拖拽移动
- 悬停时手型光标 + 放大动画

**入口:** `AppDelegate.setupFloatingIcon()`

---

### 5.2 主面板窗口 `MainPanelWindow.swift`
```swift
final class MainPanelWindow: NSPanel {
    // 默认尺寸: 320x520，最小: 320x400

    func showNear(window: NSWindow)
    func toggle(near window: NSWindow)
}
```

**入口:** `AppDelegate.setupMainPanel()`

---

### 5.3 快捷访问窗口 `QuickAccessWindow.swift`
```swift
final class QuickAccessWindow: NSPanel {
    // 200x100 起始尺寸（自适应）

    func showBelow(window: NSWindow)
    func repositionBelow(window: NSWindow)
}
```

**入口:** `AppDelegate.setupQuickAccess()`

---

### 5.4 设置窗口 `SettingsWindow.swift`
```swift
final class SettingsWindow: NSWindow {
    // 尺寸: 300x120

    func showAndActivate()
}
```

**入口:** `AppDelegate.setupSettingsWindow()`

---

## 6. 快捷键

| 快捷键 | 功能 | 实现位置 |
|--------|------|---------|
| Cmd+P | 显示/隐藏面板 | `AppDelegate.toggleMainPanel()` |
| Cmd+F | 显示/隐藏悬浮图标 | `AppDelegate.toggleFloatingIcon()` |
| Cmd+, | 打开偏好设置 | `AppDelegate.openPreferences()` |
| Cmd+Q | 退出应用 | `AppDelegate.quitApp()` |

---

## 7. 窗口层级

```
NSWindow.Level (高 → 低)
├── .screenSaver
│   ├── FloatingIconWindow  (悬浮图标)
│   └── QuickAccessWindow   (快捷访问)
├── .floating
│   ├── MainPanelWindow     (主面板)
│   └── SettingsWindow      (设置)
└── 普通窗口
```

---

## 8. 数据存储路径

```
~/Library/Application Support/PromptWise/data.json
```

**结构:**
```json
{
  "prompts": [...],
  "categories": [...]
}
```

---

## 9. UserDefaults 存储

| Key | 类型 | 说明 |
|-----|------|------|
| `appThemeMode` | String | "dark" 或 "light" |
| `quickAccessEnabled` | Bool | 快捷访问开关 |
| `quickAccessDismissDelay` | Double | 收起延迟(秒) |
| `quickAccessItemCount` | Int | 显示条数 |
| `quickAccessCategoryId` | String? | 分类 UUID |

---

## 10. 通知机制

```swift
extension Notification.Name {
    static let openSettings = Notification.Name("com.promptwise.openSettings")
}
```

**使用场景:** 设置窗口触发，其他模块监听并响应

---

## 11. 功能修改索引

| 功能需求 | 相关文件 | 关键位置 |
|---------|---------|---------|
| 修改主题颜色 | `Models/ThemeManager.swift` | 颜色计算属性 |
| 添加/修改设置项 | `Models/ThemeManager.swift` + `Views/SettingsView.swift` | 选项数组 + Picker |
| 修改快捷按钮样式 | `Views/QuickAccessView.swift` | `QuickAccessItemView` |
| 修改悬浮图标样式 | `Windows/FloatingIconWindow.swift` | `FloatingIconContent` |
| 添加快捷键 | `AppDelegate.swift` | `menuBarItemClicked` |
| 修改数据存储格式 | `Models/PromptStore.swift` | `load()` / `save()` |
| 修改主面板布局 | `Views/MainPanelView.swift` | body |
| 添加新导入格式 | `Models/PromptStore.swift` | `importFrom*` 方法 |

---

## 12. 环境对象注入

所有视图通过 `@EnvironmentObject` 获取 `ThemeManager`:

```swift
// MainPanelView, SettingsView
@EnvironmentObject var theme: ThemeManager

// QuickAccessView
@EnvironmentObject private var theme: ThemeManager
```

**注入位置:** `AppDelegate` 的各个 `setup*` 方法中:
```swift
.environmentObject(ThemeManager.shared)
```

---

*文档版本: 2026-04-01*
