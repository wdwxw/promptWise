# PromptWise 技术文档

> 本文档作为项目索引，供技术人员快速定位代码和功能入口。

---

## 1. 项目概览

**项目名称:** PromptWise

**技术栈:** 
- Swift 5.9+
- SwiftUI + AppKit 混合架构
- Swift Charts (统计图表)
- macOS 13.0+ (Ventura)

**项目路径:** `/usr/local/work/data1/ai/promptWise/`

**构建命令:** `swift build`

**应用类型:** macOS 菜单栏工具类应用 (LSUIElement/Accessory 模式)
- 隐藏 Dock 图标 (`NSApp.setActivationPolicy(.accessory)`)
- 悬浮图标始终置顶
- 支持全局快捷访问

---

## 2. 目录结构

```
Sources/PromptWise/
├── PromptWiseApp.swift              # 应用入口 (@main)
├── AppDelegate.swift                # 应用代理，核心协调器
├── Models/
│   ├── Category.swift               # 分类数据模型
│   ├── Prompt.swift                 # 提示语数据模型
│   ├── PromptCollection.swift       # 提示语集合模型
│   ├── PromptStore.swift            # 数据存储与业务逻辑中枢
│   ├── ThemeManager.swift           # 主题系统管理
│   ├── HotKeyManager.swift          # 全局快捷键管理 (EventTap)
│   ├── AIModelConfig.swift          # AI 模型配置数据模型 ⭐
│   ├── AIModelConfigStore.swift     # AI 模型配置存储与管理 ⭐
│   ├── AIService.swift              # AI 服务（API 调用、日志系统） ⭐
│   ├── PromptInputSession.swift     # 提示语优化会话数据模型 ⭐
│   └── PromptInputSessionStore.swift # 提示语优化会话存储 ⭐
├── Views/
│   ├── MainPanelView.swift          # 主面板视图 + 窗口控制器
│   ├── PromptListView.swift         # 列表/宫格视图 + 拖拽逻辑
│   ├── PromptEditView.swift         # 新建/编辑提示语
│   ├── PromptDragSource.swift       # 拖拽功能实现 (NSDraggingSource)
│   ├── PromptStatsView.swift        # 使用统计视图 (Swift Charts)
│   ├── PromptCollectionManagerView.swift   # 集合管理视图
│   ├── PromptCollectionCreatorView.swift   # 集合创建/编辑器
│   ├── CategoryManagerView.swift    # 分类管理
│   ├── ImportView.swift             # 批量导入
│   ├── QuickAccessView.swift        # 快捷访问视图
│   ├── SettingsView.swift           # 设置视图
│   ├── HotKeyRecorderView.swift     # 全局快捷键录制视图
│   ├── PromptInputView.swift        # 提示语输入与 AI 优化视图 ⭐
│   ├── AIModelConfigListView.swift  # AI 模型配置列表视图 ⭐
│   └── AIModelConfigEditorView.swift # AI 模型配置编辑器 ⭐
└── Windows/
    ├── FloatingIconWindow.swift     # 悬浮图标窗口 (56x56)
    ├── MainPanelWindow.swift        # 主面板窗口 (320x520)
    ├── QuickAccessWindow.swift      # 快捷访问窗口 (自适应)
    ├── SettingsWindow.swift         # 设置窗口 (300x自适应)
    └── PromptInputWindow.swift      # 提示语输入窗口 (450x420) ⭐
```

> ⭐ 标记为 AI 优化功能相关的新增文件

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
    var title: String           // 标题
    var content: String         // 提示语内容 (支持 Markdown)
    var categoryId: UUID?       // 所属分类
    var isStarred: Bool         // 是否标星
    var order: Int              // 排序
    var createdAt: Date
    var updatedAt: Date
    var usageCount: Int         // 累计使用次数（复制 + 拖拽）
    var recentUsages: [Date]    // 最近30天的使用时间戳

    // Markdown 转纯文本
    var plainTextContent: String { ... }
}
```

#### `PromptStore.swift` ⭐ 数据中枢
```swift
@MainActor
final class PromptStore: ObservableObject {
    @Published var prompts: [Prompt] = []
    @Published var categories: [Category] = []
    @Published var collections: [PromptCollection] = []
    private let fileURL: URL  // ~/Library/Application Support/PromptWise/data.json
}
```

**CRUD 操作:**
- `addPrompt(_:)` → 添加提示语 (根据 dataAddPosition 插入顶部或末尾)
- `updatePrompt(_:)` → 更新提示语
- `deletePrompt(id:)` → 删除提示语
- `toggleStar(id:)` → 切换星标 (标星后自动移至顶部)
- `movePrompt(from:to:)` / `movePrompt(id:toIndex:)` → 调整顺序

**查询操作:**
- `prompts(for categoryId:)` → 获取分类下的提示语
- `searchPrompts(query:categoryId:)` → 搜索提示语 (支持标题和内容模糊匹配)

**使用统计:**
- `recordUsage(id:)` → 记录一次使用，更新累计次数和近30天时间戳
- `clearAllUsageStats()` → 清除所有统计
- `clearRecentUsageStats()` → 只清除近7天记录

**集合管理:**
- `addCollection(_:)` → 添加集合
- `updateCollection(_:)` → 更新集合
- `deleteCollection(id:)` → 删除集合
- `prompts(in collection:)` → 获取集合中的提示语

**导入导出:**
- `exportData() -> Data?` → 导出 JSON
- `importFromText(_:)` → 智能识别格式 (JSON/Markdown) 并导入
- `addOrOverwritePrompt(_:)` → 静默覆盖 (标题已存在则更新)

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
    @Published var quickAccessItemsPerColumn: Int  // 5/10 条
    @Published var quickAccessCategoryId: UUID?    // 快捷访问筛选分类
    @Published var dataAddPosition: DataAddPosition // .top / .bottom
    
    // 全局快捷键配置
    @Published var globalHotKeyCode: Int           // keyCode (-1 表示未设置)
    @Published var globalHotKeyModifiers: UInt64   // CGEventFlags rawValue
    @Published var globalHotKeyEnabled: Bool
    
    // 提示语输入快捷键配置
    @Published var promptInputHotKeyCode: Int
    @Published var promptInputHotKeyModifiers: UInt64
    @Published var promptInputHotKeyEnabled: Bool
    @Published var promptInputDraft: String        // 输入框草稿
    
    // Debug 模式
    @Published var debugModeEnabled: Bool          // 控制 AI 服务日志输出
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

**结构:**
1. **集合区域** (顶部): 显示所有提示语集合，深紫浆果色胶囊样式
2. **快捷列表区域**: 按序号显示最近使用的提示语，支持多列布局 (每列最多10条)

**快捷按钮样式:**
- 深色模式: `Color.black.opacity(0.65)` 背景 + 白色文字
- 浅色模式: `Color.white.opacity(0.65)` 背景 + 深色文字
- 悬停时: 紫色半透明背景 + 白色文字
- 集合高亮时: 橙色背景高亮关联的提示语

**交互:**
- 点击: 复制内容到剪贴板
- 拖拽: 拖出到外部应用
- 悬停集合: 高亮显示集合内包含的提示语

**入口:** `AppDelegate.setupQuickAccess()` → `QuickAccessWindow`

---

### 4.7 设置视图 `SettingsView.swift`
**职责:** 应用设置界面

**配置项:**
1. **主题切换**: 深色/浅色模式
2. **数据新增位置**: 顶部追加 / 末尾追加
3. **快捷图标设置**:
   - 悬停展开开关
   - 显示条数 (5/10/15/20/30/50)
   - 每列条数 (5/10)
   - 自动收起延迟 (0.5/1/2/3/5/8/10秒)
   - 显示分类筛选
4. **全局快捷键设置**:
   - 启用开关
   - 快捷键录制
   - 辅助功能授权状态
5. **提示语输入快捷键设置**: ⭐
   - 启用开关
   - 快捷键录制
6. **数据统计**: 查看提示语使用统计 (打开 PromptStatsView)
7. **开发调试**: ⭐
   - Debug 模式开关
   - 日志文件位置（点击在 Finder 中显示）

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

### 5.5 提示语输入窗口 `PromptInputWindow.swift` ⭐
```swift
final class PromptInputWindow: NSPanel {
    // 尺寸: 450x420
    // 级别: .floating
    // 特性: 无标题栏、圆角、可拖拽

    func showAtCenter()
    func toggle()
}
```

**快捷键:** Control+Option+I (可自定义)

**入口:** `AppDelegate.setupPromptInputWindow()`

---

## 6. 快捷键

### 6.1 应用快捷键

| 快捷键 | 功能 | 实现位置 |
|--------|------|---------|
| Cmd+P | 显示/隐藏面板 | `AppDelegate.toggleMainPanel()` |
| Cmd+F | 显示/隐藏悬浮图标 | `AppDelegate.toggleFloatingIcon()` |
| Cmd+, | 打开偏好设置 | `AppDelegate.openPreferences()` |
| Cmd+Q | 退出应用 | `AppDelegate.quitApp()` |

### 6.2 全局快捷键 (可自定义)

| 默认快捷键 | 功能 | 配置位置 |
|-----------|------|---------|
| Control+Option+Space | 呼出悬浮图标 | 设置 → 全局快捷键 |
| Control+Option+I | 呼出提示语输入框 ⭐ | 设置 → 输入快捷键 |

**实现:** `HotKeyManager.swift` - 基于 CGEventTap 的全局事件监听

---

## 7. 窗口层级

```
NSWindow.Level (高 → 低)
├── .screenSaver
│   ├── FloatingIconWindow  (悬浮图标)
│   └── QuickAccessWindow   (快捷访问)
├── .floating
│   ├── MainPanelWindow     (主面板)
│   ├── SettingsWindow      (设置)
│   └── PromptInputWindow   (提示语输入) ⭐
└── 普通窗口
```

---

## 8. 数据存储路径

```
~/Library/Application Support/PromptWise/
├── data.json           # 提示语、分类、集合数据
├── models.json         # AI 模型配置 ⭐
├── session.json        # 提示语优化会话（版本历史） ⭐
└── logs/
    └── ai_service.log  # AI 服务日志（Debug 模式） ⭐
```

**data.json 结构:**
```json
{
  "prompts": [...],
  "categories": [...],
  "collections": [...]
}
```

**models.json 结构:** ⭐
```json
[
  {
    "id": "uuid",
    "name": "本地 Ollama",
    "apiFormat": "ollama",
    "baseURL": "http://localhost:11434",
    "apiKey": "",
    "modelName": "qwen3:4b",
    "systemPrompt": "你是一个提示语优化专家...",
    "temperature": 0.7,
    "maxTokens": 2048,
    "streamEnabled": true,
    "thinkEnabled": true,
    "order": 0,
    "createdAt": "2026-04-18T10:00:00Z",
    "updatedAt": "2026-04-18T10:00:00Z"
  }
]
```

**session.json 结构:** ⭐
```json
{
  "originalContent": "用户输入的原始内容",
  "versions": [
    {
      "id": "uuid",
      "index": 1,
      "content": "AI 优化后的内容",
      "modelConfigId": "uuid",
      "modelConfigName": "本地 Ollama",
      "createdAt": "2026-04-18T10:00:00Z"
    }
  ],
  "selectedVersionId": "uuid",
  "versionCounter": 1,
  "lastUpdatedAt": "2026-04-18T10:00:00Z"
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
| `quickAccessItemsPerColumn` | Int | 每列显示条数 |
| `quickAccessCategoryId` | String? | 分类 UUID |
| `dataAddPosition` | String | "top" 或 "bottom"，新数据插入位置 |
| `globalHotKeyCode` | Int | 全局快捷键 keyCode |
| `globalHotKeyModifiers` | UInt64 | 全局快捷键修饰键 |
| `globalHotKeyEnabled` | Bool | 全局快捷键开关 |
| `promptInputHotKeyCode` | Int | 提示语输入快捷键 keyCode ⭐ |
| `promptInputHotKeyModifiers` | UInt64 | 提示语输入快捷键修饰键 ⭐ |
| `promptInputHotKeyEnabled` | Bool | 提示语输入快捷键开关 ⭐ |
| `promptInputDraft` | String | 提示语输入框草稿 ⭐ |
| `debugModeEnabled` | Bool | Debug 模式开关（AI 日志） ⭐ |
| `selectedAIModelConfigId` | String? | 当前选中的 AI 模型配置 ID ⭐ |

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
| 修改全局快捷键 | `Models/HotKeyManager.swift` | `handleKeyEvent()` |
| 添加 AI 模型参数 | `Models/AIModelConfig.swift` + `Views/AIModelConfigEditorView.swift` + `Models/AIService.swift` | 模型、视图、服务 |
| 修改 AI 日志格式 | `Models/AIService.swift` | `AILogger` 类 |
| 修改提示语输入界面 | `Views/PromptInputView.swift` | body + 状态管理 |

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

## 13. 窗口控制器架构

### 13.1 PromptEditWindowController
独立窗口控制器，用于新建/编辑提示语：

```swift
final class PromptEditWindowController: NSObject, NSWindowDelegate {
    private let window: DraggableWindow  // 支持拖动的 NSPanel
    private let onDismiss: () -> Void
    
    // 窗口配置
    - 尺寸: 480x520
    - level: .floating
    - hidesOnDeactivate: false
    - 标题栏: 隐藏 (titleVisibility = .hidden)
}
```

**核心方法:**
- `showWindow()` - 显示并激活窗口
- `close()` - 关闭窗口
- `windowWillClose(_:)` - 代理回调，触发 onDismiss

### 13.2 CollectionWindowController
集合管理窗口控制器：

```swift
final class CollectionWindowController: NSObject, NSWindowDelegate {
    // 尺寸: 360x400
    // 承载 PromptCollectionManagerView
}
```

---

## 14. 拖拽系统实现

### 14.1 列表拖拽 (PromptDragHandle)
基于 `NSView` + `NSDraggingSource` 实现：

```swift
struct PromptDragHandle: NSViewRepresentable {
    let prompt: Prompt
    let onDragStarted: (Prompt) -> Void
    let onDragEnded: () -> Void
    var onExternalDrop: ((Prompt) -> Void)? = nil
}
```

**实现细节:**
- 继承 `NSView`，实现 `NSDraggingSource` 协议
- 拖拽阈值: 3 像素 (`sqrt(dx*dx + dy*dy) > 3`)
- 拖拽图像: 动态生成，显示提示语标题
- 内部拖拽: `.move` 操作，支持重排序
- 外部拖拽: `.copy` 操作，拖拽到其他应用

### 14.2 宫格/快捷访问拖拽 (DraggablePromptOverlay)
透明覆盖层实现点击和拖拽共存：

```swift
struct DraggablePromptOverlay: NSViewRepresentable {
    let prompt: Prompt
    let onDragStarted: (Prompt) -> Void
    let onDragEnded: () -> Void
    let onTap: () -> Void
    var onExternalDrop: ((Prompt) -> Void)? = nil
}
```

**关键行为:**
- 短按 (无拖拽): 触发 `onTap` (复制到剪贴板)
- 拖拽: 触发 `onDragStarted`，内容拖出
- 释放到外部: 触发 `onExternalDrop` (记录使用统计)

### 14.3 集合编辑器拖拽
支持跨面板拖放：
- 左侧面板 → 右侧面板: 添加提示语到集合
- 使用 `NSItemProvider` 传递 UUID 字符串
- 支持 `UTType.text`, `UTType.plainText`, `UTType.utf8PlainText`

---

## 15. 使用统计系统

### 15.1 数据结构
```swift
struct Prompt {
    /// 累计使用次数（复制 + 拖拽）
    var usageCount: Int
    /// 最近 30 天的使用时间戳（用于计算近 7 天使用数）
    var recentUsages: [Date]
}
```

### 15.2 统计逻辑
```swift
/// 记录一次使用（复制或拖拽）
func recordUsage(id: UUID) {
    let now = Date()
    let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now)!
    prompts[index].usageCount += 1
    prompts[index].recentUsages.append(now)
    // 清理超过 30 天的记录
    prompts[index].recentUsages = prompts[index].recentUsages.filter { $0 >= cutoff }
}
```

### 15.3 统计视图 (PromptStatsView)
- 提示语总数
- 累计使用次数
- 近 7 天使用次数
- 使用次数 Top 10 图表 (Swift Charts)
- 全部提示语使用明细表

---

## 16. 集合系统 (PromptCollection)

### 16.1 数据模型
```swift
struct PromptCollection: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    /// 有序的提示语 ID 列表
    var promptIds: [UUID]
    var createdAt: Date
    var updatedAt: Date
}
```

### 16.2 核心功能
- **创建集合**: 从左侧面板拖拽提示语到右侧
- **编辑集合**: 修改标题、调整顺序、增删提示语
- **复制集合**: 合并所有提示语内容到剪贴板
- **高亮联动**: 悬停集合时高亮显示其包含的提示语

### 16.3 快捷访问集成
集合显示在快捷访问面板顶部：
- 深紫浆果色胶囊样式 (`Color(red: 147/255, green: 51/255, blue: 234/255)`)
- 显示集合内提示语数量
- 点击复制全部内容
- 支持拖拽导出

---

## 17. 窗口层级与交互

### 17.1 窗口层级 (NSWindow.Level)
```
.screenSaver (最高)
├── FloatingIconWindow    (悬浮图标，96x96)
└── QuickAccessWindow     (快捷访问，自适应)

.floating
├── MainPanelWindow       (主面板，320x520)
└── SettingsWindow        (设置，300x自适应)
```

### 17.2 Sheet 重叠处理
自动检测并避免 Sheet 与悬浮图标重叠：
```swift
private func repositionSheetWindowIfOverlapsIcon(_ window: NSWindow) {
    // 给悬浮图标加 16px 缓冲区
    let iconGuard = iconFrame.insetBy(dx: -16, dy: -16)
    if window.frame.intersects(iconGuard) {
        // 根据图标位置，将 sheet 移到左侧或右侧
    }
}
```

---

## 18. Token 估算算法

编辑视图实时显示 Token 估算：
```swift
private var tokenEstimate: Int {
    guard !content.isEmpty else { return 0 }
    // CJK 汉字: 1 字 ≈ 1 Token
    let cjkCount = content.unicodeScalars.filter {
        ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||      // CJK 统一汉字
        ($0.value >= 0x3400 && $0.value <= 0x4DBF) ||      // CJK 扩展A
        ($0.value >= 0x20000 && $0.value <= 0x2A6DF)       // CJK 扩展B
    }.count
    // 其他字符: 4 字 ≈ 1 Token
    let otherCount = content.count - cjkCount
    return cjkCount + max(0, Int(ceil(Double(otherCount) / 4.0)))
}
```

---

## 19. 悬浮图标交互设计

### 19.1 主题切换节点
悬浮图标周围集成两个主题切换按钮：
- **太阳图标** (太阳色 `#f59e0b`): 切换到浅色模式，角度 136°-15°
- **月亮图标** (月亮色 `#2563eb`): 切换到深色模式，角度 136°+15°
- 轨道半径: 40px (`orbitRadius = 40`)
- 点击热区半径: 12px

### 19.2 拖拽移动
- 拖拽阈值: 2 像素
- 窗口级别: `.statusBar` (始终置顶)
- 拖动时隐藏主面板和快捷访问面板

---

## 20. 导入导出格式

### 20.1 JSON 格式
```json
{
  "prompts": [
    {
      "id": "uuid",
      "title": "标题",
      "content": "内容",
      "categoryId": "uuid",
      "isStarred": false,
      "order": 0,
      "createdAt": "2026-04-15T10:00:00Z",
      "updatedAt": "2026-04-15T10:00:00Z",
      "usageCount": 0,
      "recentUsages": []
    }
  ],
  "categories": [...],
  "collections": [...]
}
```

### 20.2 Markdown 格式
```markdown
## 标题1
内容...

## 标题2
内容...
```

### 20.3 简单 JSON 兼容
```json
[{"title":"标题", "content":"内容"}]
```

---

## 21. 关键设计模式

### 21.1 单例模式
```swift
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private init() { ... }
}
```

### 21.2 观察者模式
```swift
// 设置打开通知
extension Notification.Name {
    static let openSettings = Notification.Name("com.promptwise.openSettings")
}
```

### 21.3 窗口协调模式
AppDelegate 作为中央协调器：
- 管理所有窗口实例
- 处理窗口间通信
- 维护悬停状态 (`iconHovered`, `qaHovered`)

---

## 22. 性能优化

### 22.1 LazyVStack / LazyVGrid
- 列表和宫格使用惰性加载
- 大数据集时优化内存使用

### 22.2 异步延迟操作
```swift
// 悬停预览延迟 0.6 秒触发
DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
    if isHovered { showPopover = true }
}

// 快捷访问收起延迟
DispatchQueue.main.asyncAfter(
    deadline: .now() + ThemeManager.shared.quickAccessDismissDelay
) { ... }
```

### 22.3 数据持久化
- 自动保存: 每次数据变更后调用 `save()`
- 原子写入: `options: .atomic`
- 日期格式: ISO8601

---

## 23. 开发规范

### 23.1 文件组织
```
Sources/PromptWise/
├── Models/          # 数据模型 + 业务逻辑
├── Views/           # SwiftUI 视图
├── Windows/         # NSWindow/NSPanel 封装
├── PromptWiseApp.swift    # 应用入口
└── AppDelegate.swift      # 应用代理
```

### 23.2 命名规范
- 视图: `*View.swift`
- 窗口: `*Window.swift`
- 模型: 名词命名 (`Prompt`, `Category`)
- 控制器: `*WindowController`

### 23.3 颜色管理
所有颜色通过 `ThemeManager` 统一管理：
```swift
@EnvironmentObject var theme: ThemeManager
...
.background(theme.panelBg)
.foregroundStyle(theme.textPrimary)
```

---

## 24. 功能修改索引 (扩展)

| 功能需求 | 相关文件 | 关键位置 |
|---------|---------|---------|
| 修改 Token 估算算法 | `PromptEditView.swift` | `tokenEstimate` 计算属性 |
| 修改拖拽阈值 | `PromptDragSource.swift` | `sqrt(dx*dx + dy*dy) > 3` |
| 添加统计维度 | `PromptStatsView.swift` | `summarySection` / `chartSection` |
| 修改集合样式 | `QuickAccessView.swift` | `CollectionQuickItemView` |
| 修改导入格式 | `PromptStore.swift` | `importFrom*` 方法 |
| 修改数据保留策略 | `PromptStore.swift` | `recordUsage` 中 cutoff 计算 |

---

---

## 25. AI 提示语优化功能 ⭐

### 25.1 功能概述
通过 AI 模型对用户输入的提示语进行优化，支持多版本管理和持久化存储。

**核心特性:**
- 支持 Ollama 和 OpenAI 格式 API
- 流式输出实时显示
- 多版本历史管理
- 思考模式控制（Ollama think 参数）
- Debug 日志系统

### 25.2 数据模型

#### `AIModelConfig.swift` - AI 模型配置
```swift
enum APIFormat: String, Codable, CaseIterable {
    case openai = "openai"    // OpenAI Chat Completions 格式
    case ollama = "ollama"    // Ollama API 格式
}

struct AIModelConfig: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String              // 配置名称
    var apiFormat: APIFormat      // API 格式
    var baseURL: String           // Base URL
    var apiKey: String            // API Key (Ollama 可空)
    var modelName: String         // 模型名称
    var systemPrompt: String      // 系统提示语
    var temperature: Double       // 温度 (0.0 - 2.0)
    var maxTokens: Int            // Token 上限
    var streamEnabled: Bool       // 流式输出开关
    var thinkEnabled: Bool        // 思考模式开关 (Ollama)
    var order: Int
    var createdAt: Date
    var updatedAt: Date
}
```

#### `PromptInputSession.swift` - 优化会话
```swift
struct OptimizedVersion: Identifiable, Codable, Hashable {
    var id: UUID
    var index: Int                // 版本序号 (1, 2, 3...)
    var content: String           // 优化后内容
    var modelConfigId: UUID       // 使用的模型配置
    var modelConfigName: String   // 模型配置名称
    var createdAt: Date
}

struct PromptInputSession: Codable {
    var originalContent: String           // 用户原始输入
    var versions: [OptimizedVersion]      // 优化版本列表
    var selectedVersionId: UUID?          // 当前选中版本
    var versionCounter: Int               // 版本计数器
    var lastUpdatedAt: Date
    
    var currentContent: String { ... }    // 当前显示内容
}
```

### 25.3 AI 服务 (`AIService.swift`)

```swift
@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()
    
    // Ollama 模型列表获取
    func fetchOllamaModels(baseURL: String) async throws -> [String]
    
    // 非流式优化
    func optimize(userPrompt: String, config: AIModelConfig) async throws -> String
    
    // 流式优化
    func optimizeStream(
        userPrompt: String,
        config: AIModelConfig,
        onChunk: @escaping (String) -> Void
    ) async throws
}
```

**API 格式支持:**

| 格式 | 端点 | 特性 |
|-----|------|------|
| Ollama | `/api/generate` | 支持 `think` 参数、流式/非流式 |
| OpenAI | `/v1/chat/completions` | 标准 Chat Completions API |

**思考模式参数 (Ollama):**
- `think: false` - 关闭思考模式，响应更快
- 不传 `think` - 使用模型默认行为
- 支持模型: Qwen3, DeepSeek R1, Gemma 4 等

### 25.4 日志系统 (`AILogger`)

```swift
final class AILogger {
    static let shared = AILogger()
    
    var isDebugEnabled: Bool { UserDefaults... }
    var logFilePath: String { ... }
    
    func log(_ message: String, level: String = "INFO")
    func error(_ message: String)
    func debug(_ message: String)
    
    // 详细请求/响应日志
    func logRequest(method:, url:, headers:, body:)
    func logResponse(statusCode:, headers:, body:, truncateAt:)
    func logStreamChunk(_ chunk: String, index: Int)
}
```

**日志路径:** `~/Library/Application Support/PromptWise/logs/ai_service.log`

**日志控制:** 设置 → 开发调试 → 启用 Debug 模式

### 25.5 界面组件

#### `PromptInputView.swift` - 主界面
```
┌────────────────────────────────────────┐
│ 提示语输入                    [⚙️]      │ ← 标题栏 + 设置按钮
├────────────────────────────────────────┤
│ [当前] [提示语1] [提示语2]   [清除]    │ ← 状态条（版本切换）
├────────────────────────────────────────┤
│                                        │
│   ┌──────────────────────────────┐    │
│   │                              │    │
│   │     文本编辑区域              │    │ ← 主编辑器
│   │                              │    │
│   └──────────────────────────────┘    │
│                                        │
├────────────────────────────────────────┤
│ 字符: 123 | Token: ~45                 │ ← 统计信息
├────────────────────────────────────────┤
│ [选择模型 ▾]    [优化/停止]    [复制]  │ ← 底部操作栏
└────────────────────────────────────────┘
```

**关键状态:**
```swift
@State private var text: String = ""
@State private var isOptimizing = false
@State private var isCancelled = false
@State private var currentStreamingVersionId: UUID?
@State private var optimizeTask: Task<Void, Never>?
```

#### `AIModelConfigListView.swift` - 配置列表
- 显示所有 AI 模型配置
- 支持新增、编辑、删除
- 支持拖拽排序
- 当前选中配置高亮

#### `AIModelConfigEditorView.swift` - 配置编辑器
- 基本信息: 名称、API 格式
- 连接设置: Base URL、API Key、模型名称
- 系统提示语
- 参数设置: 温度、Token 上限、流式输出、思考模式

### 25.6 窗口 (`PromptInputWindow.swift`)

```swift
final class PromptInputWindow: NSPanel {
    // 尺寸: 450x420
    // 级别: .floating
    // 特性: 无标题栏、圆角、可拖拽
    
    func showAtCenter()
    func toggle()
}
```

**快捷键:** Control+Option+I (默认，可自定义)

### 25.7 流式输出控制

**启动优化:**
```swift
optimizeTask = Task { await startOptimize() }
```

**停止优化:**
```swift
func stopOptimize() {
    isCancelled = true
    optimizeTask?.cancel()
    optimizeTask = nil
    isOptimizing = false
}
```

**自动停止场景:**
- 点击"停止"按钮
- 点击"清除"按钮
- 切换到其他版本

### 25.8 版本管理

| 操作 | 行为 |
|-----|------|
| 点击"当前" | 显示原始输入 |
| 点击"提示语N" | 显示第 N 个优化版本 |
| 点击"优化" | 创建新版本并开始流式输出 |
| 点击"清除" | 删除所有优化版本 |
| 流式输出中 | 版本按钮显示"生成中..." |

### 25.9 功能修改索引

| 功能需求 | 相关文件 | 关键位置 |
|---------|---------|---------|
| 添加新 API 格式 | `AIModelConfig.swift`, `AIService.swift` | `APIFormat` 枚举, `optimize*` 方法 |
| 修改默认系统提示语 | `AIModelConfig.swift` | `defaultOllama()`, `defaultOpenAI()` |
| 修改日志格式 | `AIService.swift` | `AILogger` 类 |
| 修改 Token 估算 | `PromptInputView.swift` | `estimatedTokenCount` |
| 修改版本按钮样式 | `PromptInputView.swift` | `versionButton()` |
| 添加新参数 | `AIModelConfig.swift`, `AIModelConfigEditorView.swift`, `AIService.swift` | 模型、视图、服务三处 |

---

*文档版本: 2026-04-18*
