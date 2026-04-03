import SwiftUI
import UniformTypeIdentifiers

// Theme colors are now managed by ThemeManager

enum ViewMode: String, CaseIterable {
    case list = "列表"
    case grid = "宫格"

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

struct MainPanelView: View {
    @ObservedObject var store: PromptStore
    @EnvironmentObject var theme: ThemeManager
    let onClose: () -> Void

    @State private var searchText = ""
    @State private var selectedCategoryId: UUID?
    @State private var viewMode: ViewMode = .list
    @State private var showingAddPrompt = false
    @State private var showingCategoryManager = false
    @State private var editingPrompt: Prompt?
    @State private var copiedPromptId: UUID?
    @State private var showingImport = false
    @State private var showingCollectionManager = false

    // PromptEditView 窗口控制器
    @State private var promptEditWindowController: PromptEditWindowController?
    @State private var promptEditPrompt: Prompt? // 要编辑的提示语（nil 表示新建）
    @State private var promptEditDefaultCategoryId: UUID? // 新建时的默认分类

    // PromptCollectionWindow 管理
    @State private var collectionWindowController: CollectionWindowController?

    private var filteredPrompts: [Prompt] {
        store.searchPrompts(query: searchText, categoryId: selectedCategoryId)
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            divider
            categoryBar
            searchBar
            divider
            promptContent
        }
        .frame(minWidth: 320, minHeight: 400)
        .background(theme.panelBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.border, lineWidth: 1)
        )
        .environment(\.colorScheme, theme.mode == .dark ? .dark : .light)
        .onChange(of: showingAddPrompt) { newValue in
            if newValue {
                showPromptEditWindow(prompt: nil, defaultCategoryId: selectedCategoryId)
            } else {
                // 延迟关闭，确保 sheet 先完成关闭动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [promptEditWindowController] in
                    promptEditWindowController?.close()
                }
            }
        }
        .onChange(of: editingPrompt) { newValue in
            if let prompt = newValue {
                showPromptEditWindow(prompt: prompt, defaultCategoryId: nil)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [promptEditWindowController] in
                    promptEditWindowController?.close()
                }
            }
        }
        .sheet(isPresented: $showingCategoryManager) {
            CategoryManagerView(store: store)
        }
        .sheet(isPresented: $showingImport) {
            ImportView(store: store)
        }
        .onChange(of: showingCollectionManager) { newValue in
            if newValue {
                showCollectionWindow()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [collectionWindowController] in
                    collectionWindowController?.close()
                }
            }
        }
    }

    // MARK: - PromptEditWindow Management

    private func showCollectionWindow() {
        collectionWindowController?.close()

        let controller = CollectionWindowController(
            store: store,
            theme: theme,
            onDismiss: { [self] in
                DispatchQueue.main.async {
                    self.showingCollectionManager = false
                }
            }
        )
        collectionWindowController = controller
        controller.showWindow()
    }

    private func showPromptEditWindow(prompt: Prompt?, defaultCategoryId: UUID?) {
        // 关闭之前的窗口
        promptEditWindowController?.close()

        let controller = PromptEditWindowController(
            store: store,
            prompt: prompt,
            defaultCategoryId: defaultCategoryId,
            onDismiss: { [self] in
                // 注意：由于 SwiftUI View 是值类型，这里使用 [self] 捕获
                // 窗口关闭时，重置状态
                DispatchQueue.main.async {
                    self.showingAddPrompt = false
                    self.editingPrompt = nil
                }
            }
        )
        promptEditWindowController = controller
        controller.showWindow()
    }

    private var divider: some View {
        Rectangle().fill(theme.border).frame(height: 1)
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 8) {
            Text("⚡")
                .font(.system(size: 14))

            Text("提示语")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Text("\(store.prompts.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.iconOnSurface)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(theme.surfaceBg)
                .clipShape(Capsule())

            Spacer()

            headerButton(icon: "plus", label: "新建") {
                if showingAddPrompt {
                    promptEditWindowController?.showWindow()
                } else {
                    showingAddPrompt = true
                }
            }

            Menu {
                Button { showingCategoryManager = true } label: {
                    Label("分类管理", systemImage: "folder")
                }
                Divider()
                Button { showingImport = true } label: {
                    Label("批量导入...", systemImage: "square.and.arrow.down")
                }
                Button { exportPrompts() } label: {
                    Label("导出数据...", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                } label: {
                    Label("设置...", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.iconOnSurface)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.surfaceBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.iconOnSurface)
                    .frame(width: 20, height: 20)
                    .background(theme.surfaceBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 集合入口胶囊按钮（固定在分类栏右侧）
    private var collectionButton: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: {
                if showingCollectionManager {
                    collectionWindowController?.showWindow()
                } else {
                    showingCollectionManager = true
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 10))
                    Text("集合")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(store.collections.isEmpty ? theme.textTertiary : Color.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    store.collections.isEmpty
                        ? Color.clear
                        : Color.orange.opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            store.collections.isEmpty
                                ? theme.textTertiary.opacity(0.2)
                                : Color.orange.opacity(0.3),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)

            if !store.collections.isEmpty {
                Text("\(store.collections.count)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.orange)
                    .clipShape(Capsule())
                    .offset(x: 5, y: -5)
            }
        }
    }

    private func headerButton(icon: String, label: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                if let label {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundStyle(theme.iconOnSurface)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    CategoryChip(
                        name: "全部",
                        icon: "tray.full",
                        isSelected: selectedCategoryId == nil,
                        action: { selectedCategoryId = nil }
                    )

                    ForEach(store.categories) { category in
                        CategoryChip(
                            name: category.name,
                            icon: category.icon,
                            isSelected: selectedCategoryId == category.id,
                            action: { selectedCategoryId = category.id }
                        )
                    }
                }
                .padding(.leading, 14)
                .padding(.vertical, 8)
            }

            // 集合入口（固定在分类栏右侧）
            collectionButton
                .padding(.trailing, 14)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textPrimary)
                    .font(.system(size: 11))

                TextField("搜索...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textPrimary)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textPrimary)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(theme.border, lineWidth: 1)
            )

            CustomSegmentedControl(selection: $viewMode)
                .frame(width: 64)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var promptContent: some View {
        if filteredPrompts.isEmpty {
            emptyState
        } else {
            switch viewMode {
            case .list:
                PromptListView(
                    prompts: filteredPrompts,
                    store: store,
                    copiedPromptId: $copiedPromptId,
                    onEdit: { prompt in
                        if editingPrompt == prompt {
                            promptEditWindowController?.showWindow()
                        } else {
                            editingPrompt = prompt
                        }
                    },
                    onCopy: copyPrompt,
                    onExternalDrop: { store.recordUsage(id: $0.id) }
                )
            case .grid:
                PromptGridView(
                    prompts: filteredPrompts,
                    store: store,
                    copiedPromptId: $copiedPromptId,
                    onEdit: { prompt in
                        if editingPrompt == prompt {
                            promptEditWindowController?.showWindow()
                        } else {
                            editingPrompt = prompt
                        }
                    },
                    onCopy: copyPrompt,
                    onExternalDrop: { store.recordUsage(id: $0.id) }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text(searchText.isEmpty ? "还没有提示语" : "没有搜索结果")
                .font(.system(size: 13))
                .foregroundStyle(theme.textTertiary)
            if searchText.isEmpty {
                Button(action: {
                    if showingAddPrompt {
                        promptEditWindowController?.showWindow()
                    } else {
                        showingAddPrompt = true
                    }
                }) {
                    Text("＋ 新建")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.accentSubtle)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func exportPrompts() {
        guard let data = store.exportData() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "PromptWise-export.json"
        panel.title = "导出提示语数据"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func copyPrompt(_ prompt: Prompt) {
        store.recordUsage(id: prompt.id)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)

        withAnimation(.easeInOut(duration: 0.2)) {
            copiedPromptId = prompt.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                if copiedPromptId == prompt.id {
                    copiedPromptId = nil
                }
            }
        }
    }
}

// MARK: - Custom Segmented Control

struct CustomSegmentedControl: View {
    @EnvironmentObject var theme: ThemeManager
    @Binding var selection: ViewMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: { selection = mode }) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(selection == mode ? theme.textPrimary : theme.textSecondary)
                        .frame(width: 28, height: 24)
                        .background(selection == mode ? theme.surfaceBg : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(theme.border)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Category Chip (Notion style)

struct CategoryChip: View {
    @EnvironmentObject var theme: ThemeManager
    let name: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(name)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(isSelected ? theme.accentSubtle : theme.textTertiary)
            .background(isSelected ? theme.accent.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DraggableWindow

/// 支持拖动的窗口
final class DraggableWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - WindowDragArea

/// 仅在此区域内可拖动窗口（放置在 headerBar 的 background 上）
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragNSView { WindowDragNSView() }
    func updateNSView(_ nsView: WindowDragNSView, context: Context) {}

    class WindowDragNSView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

// MARK: - PromptEditWindowController

final class PromptEditWindowController: NSObject, NSWindowDelegate {
    private let window: DraggableWindow
    private let onDismiss: () -> Void
    private weak var hostingView: NSHostingView<AnyView>?

    init(store: PromptStore, prompt: Prompt?, defaultCategoryId: UUID?, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss

        // 创建支持拖动的窗口
        window = DraggableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false

        super.init()

        window.title = prompt == nil ? "新增提示语" : "编辑提示语"
        window.level = .floating
        window.hidesOnDeactivate = false
        window.delegate = self
        window.center()

        // 创建 PromptEditView 并包装以便关闭
        let promptEditView = PromptEditView(
            store: store,
            prompt: prompt,
            defaultCategoryId: defaultCategoryId,
            onDismiss: { [weak self] in
                self?.window.close()
            }
        )

        let containerView = AnyView(promptEditView)
        let hosting = NSHostingView(rootView: containerView)
        hostingView = hosting
        window.contentView = hosting
    }

    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时调用 onDismiss
        onDismiss()
    }
}

// MARK: - CollectionWindowController

final class CollectionWindowController: NSObject, NSWindowDelegate {
    private let window: DraggableWindow
    private let onDismiss: () -> Void
    private weak var hostingView: NSHostingView<AnyView>?

    init(store: PromptStore, theme: ThemeManager, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss

        // 创建支持拖动的窗口
        window = DraggableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false

        super.init()

        window.title = "提示语集合"
        window.level = .floating
        window.hidesOnDeactivate = false
        window.delegate = self
        window.center()

        // 创建 PromptCollectionManagerView 并包装以便关闭
        let view = PromptCollectionManagerView(store: store, onDismiss: { [weak self] in
            self?.window.close()
        })
        .environmentObject(theme)

        let containerView = AnyView(view)
        let hosting = NSHostingView(rootView: containerView)
        hostingView = hosting
        window.contentView = hosting
    }

    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时调用 onDismiss
        onDismiss()
    }
}
