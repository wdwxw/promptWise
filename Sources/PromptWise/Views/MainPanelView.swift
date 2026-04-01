import SwiftUI

// MARK: - Theme Constants

enum Theme {
    static let panelBg = Color(nsColor: NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1)) // #1e1e1e
    static let surfaceBg = Color(nsColor: NSColor(red: 0.145, green: 0.145, blue: 0.145, alpha: 1)) // #252525
    static let border = Color(nsColor: NSColor(red: 0.165, green: 0.165, blue: 0.165, alpha: 1)) // #2a2a2a
    static let textPrimary = Color(nsColor: NSColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)) // #bbb
    static let textSecondary = Color(nsColor: NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)) // #999
    static let textTertiary = Color(nsColor: NSColor(red: 0.333, green: 0.333, blue: 0.333, alpha: 1)) // #555
    static let accent = Color(nsColor: NSColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1)) // #7c3aed
    static let accentSubtle = Color(nsColor: NSColor(red: 0.655, green: 0.545, blue: 0.980, alpha: 1)) // #a78bfa
}

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
    let onClose: () -> Void

    @State private var searchText = ""
    @State private var selectedCategoryId: UUID?
    @State private var viewMode: ViewMode = .list
    @State private var showingAddPrompt = false
    @State private var showingCategoryManager = false
    @State private var editingPrompt: Prompt?
    @State private var copiedPromptId: UUID?

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
        .background(Theme.panelBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .sheet(isPresented: $showingAddPrompt) {
            PromptEditView(store: store, prompt: nil, defaultCategoryId: selectedCategoryId)
        }
        .sheet(item: $editingPrompt) { prompt in
            PromptEditView(store: store, prompt: prompt, defaultCategoryId: nil)
        }
        .sheet(isPresented: $showingCategoryManager) {
            CategoryManagerView(store: store)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.border).frame(height: 1)
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 8) {
            Text("⚡")
                .font(.system(size: 14))

            Text("提示语")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            headerButton(icon: "plus", label: "新建") {
                showingAddPrompt = true
            }

            headerButton(icon: "gearshape", label: nil) {
                showingCategoryManager = true
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(Theme.surfaceBg)
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
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.surfaceBg)
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
                    .foregroundStyle(Theme.textTertiary)
                    .font(.system(size: 11))

                TextField("搜索...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textTertiary)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )

            Picker("", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
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
                    onCopy: copyPrompt
                )
            case .grid:
                PromptGridView(
                    prompts: filteredPrompts,
                    store: store,
                    copiedPromptId: $copiedPromptId,
                    onEdit: { editingPrompt = $0 },
                    onCopy: copyPrompt
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(.system(size: 32))
                .foregroundStyle(Theme.textTertiary)
            Text(searchText.isEmpty ? "还没有提示语" : "没有搜索结果")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
            if searchText.isEmpty {
                Button(action: { showingAddPrompt = true }) {
                    Text("＋ 新建")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accentSubtle)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func copyPrompt(_ prompt: Prompt) {
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

// MARK: - Category Chip (Notion style)

struct CategoryChip: View {
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
            .foregroundStyle(isSelected ? Theme.accentSubtle : Theme.textTertiary)
            .background(isSelected ? Theme.accent.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
