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
│   └── ThemeManager.swift           # 主题系统管理
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
│   └── SettingsView.swift           # 设置视图
└── Windows/
    ├── FloatingIconWindow.swift     # 悬浮图标窗口 (96x96)
    ├── MainPanelWindow.swift        # 主面板窗口 (320x520)
    ├── QuickAccessWindow.swift      # 快捷访问窗口 (自适应)
    └── SettingsWindow.swift         # 设置窗口 (300x自适应)
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
    @Published var quickAccessCategoryId: UUID?    // 快捷访问筛选分类
    @Published var dataAddPosition: DataAddPosition // .top / .bottom
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
   - 自动收起延迟 (0.5/1/2/3/5/8/10秒)
   - 显示分类筛选
4. **数据统计**: 查看提示语使用统计 (打开 PromptStatsView)

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
| `dataAddPosition` | String | "top" 或 "bottom"，新数据插入位置 |

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

*文档版本: 2026-04-15*
