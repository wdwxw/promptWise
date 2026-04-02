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
        .sheet(isPresented: $showingAddPrompt) {
            PromptEditView(store: store, prompt: nil, defaultCategoryId: selectedCategoryId)
        }
        .sheet(item: $editingPrompt) { prompt in
            PromptEditView(store: store, prompt: prompt, defaultCategoryId: nil)
        }
        .sheet(isPresented: $showingCategoryManager) {
            CategoryManagerView(store: store)
        }
        .sheet(isPresented: $showingImport) {
            ImportView(store: store)
        }
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
                showingAddPrompt = true
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
            .padding(.horizontal, 14)
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
                    onEdit: { editingPrompt = $0 },
                    onCopy: copyPrompt,
                    onExternalDrop: { store.recordUsage(id: $0.id) }
                )
            case .grid:
                PromptGridView(
                    prompts: filteredPrompts,
                    store: store,
                    copiedPromptId: $copiedPromptId,
                    onEdit: { editingPrompt = $0 },
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
                Button(action: { showingAddPrompt = true }) {
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
