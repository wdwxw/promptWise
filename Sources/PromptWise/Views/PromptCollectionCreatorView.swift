import SwiftUI
import UniformTypeIdentifiers

// MARK: - Collection Creator Sheet（创建 / 编辑提示语集合）

struct PromptCollectionCreatorView: View {
    @EnvironmentObject var theme: ThemeManager
    @ObservedObject var store: PromptStore

    /// 传入表示"编辑已有集合"，nil 表示新建
    var existingCollection: PromptCollection?
    var onDismiss: () -> Void

    @State private var title: String
    @State private var selectedIds: [UUID]
    @State private var isEditingTitle = false
    @State private var isDropTargeted = false
    /// 右侧列表内拖拽排序用
    @State private var draggingId: UUID?

    init(
        store: PromptStore,
        existingCollection: PromptCollection? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.store = store
        self.existingCollection = existingCollection
        self.onDismiss = onDismiss
        _title = State(initialValue: existingCollection?.title ?? "未命名集合")
        _selectedIds = State(initialValue: existingCollection?.promptIds ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            divider
            HStack(spacing: 0) {
                leftPanel
                divider.frame(width: 1, height: nil)
                rightPanel
            }
            .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 440)
        .background(theme.panelBg)
        .environment(\.colorScheme, theme.mode == .dark ? .dark : .light)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)

            titleField

            Spacer()

            Button("取消") {
                onDismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            Button(action: saveCollection) {
                Text("保存集合")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(selectedIds.isEmpty ? Color.gray.opacity(0.4) : Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(selectedIds.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(WindowDragArea())
    }

    @ViewBuilder
    private var titleField: some View {
        if isEditingTitle {
            TextField("集合标题", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .onSubmit { isEditingTitle = false }
                .focused($titleFocused)
        } else {
            HStack(spacing: 4) {
                Text(title.isEmpty ? "未命名集合" : title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(title.isEmpty ? theme.textTertiary : theme.textPrimary)
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isEditingTitle = true
                titleFocused = true
            }
        }
    }

    @FocusState private var titleFocused: Bool

    // MARK: - Divider

    private var divider: some View {
        Rectangle().fill(theme.border).frame(height: 1)
    }

    // MARK: - Left Panel（所有可用提示语）

    private var leftPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("可用提示语")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text("\(store.prompts.count) 条")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle().fill(theme.border).frame(height: 1)

            if store.prompts.isEmpty {
                Spacer()
                Text("暂无提示语")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.prompts) { prompt in
                            LeftPanelPromptRow(
                                prompt: prompt,
                                isAdded: selectedIds.contains(prompt.id),
                                onAdd: {
                                    if !selectedIds.contains(prompt.id) {
                                        selectedIds.append(prompt.id)
                                    }
                                }
                            )
                            .onDrag {
                                NSItemProvider(object: prompt.id.uuidString as NSString)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 280)
        .background(theme.panelBg)
    }

    // MARK: - Right Panel（已选提示语 + 拖入区域）

    private var rightPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("集合内容")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if !selectedIds.isEmpty {
                    Text("\(selectedIds.count) 条")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle().fill(theme.border).frame(height: 1)

            dropZoneContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrop(
                    of: [UTType.text, UTType.plainText, UTType.utf8PlainText],
                    isTargeted: $isDropTargeted
                ) { providers in
                    handleDrop(providers: providers)
                }
        }
        .frame(maxWidth: .infinity)
        .background(theme.panelBg)
    }

    @ViewBuilder
    private var dropZoneContent: some View {
        ZStack {
            // 虚线边框（始终可见）
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .foregroundStyle(
                    isDropTargeted
                        ? Color.orange.opacity(0.8)
                        : theme.textTertiary.opacity(0.25)
                )
                .padding(12)
                .animation(.easeInOut(duration: 0.15), value: isDropTargeted)

            if selectedIds.isEmpty {
                emptyDropHint
            } else {
                selectedList
            }
        }
    }

    private var emptyDropHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.right.to.line")
                .font(.system(size: 28))
                .foregroundStyle(
                    isDropTargeted ? Color.orange : theme.textTertiary.opacity(0.4)
                )
                .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
            Text("从左侧拖入提示语")
                .font(.system(size: 12))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var selectedList: some View {
        List {
            ForEach(selectedIds, id: \.self) { id in
                if let prompt = store.prompts.first(where: { $0.id == id }) {
                    RightPanelPromptRow(
                        prompt: prompt,
                        onRemove: {
                            selectedIds.removeAll { $0 == id }
                        }
                    )
                    .listRowBackground(theme.panelBg)
                    .listRowSeparatorTint(theme.border)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }
            }
            .onMove { from, to in
                selectedIds.move(fromOffsets: from, toOffset: to)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 12)
    }

    // MARK: - Drop Handler

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // NSString 对应 .onDrag { NSItemProvider(object: string as NSString) } 产生的拖拽数据
            _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
                guard let str = obj as? String, let id = UUID(uuidString: str) else { return }
                DispatchQueue.main.async {
                    if !self.selectedIds.contains(id) {
                        self.selectedIds.append(id)
                    }
                }
            }
        }
        return true
    }

    // MARK: - Save

    private func saveCollection() {
        guard !selectedIds.isEmpty else { return }
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if var existing = existingCollection {
            existing.title = finalTitle.isEmpty ? "未命名集合" : finalTitle
            existing.promptIds = selectedIds
            store.updateCollection(existing)
        } else {
            let collection = PromptCollection(
                title: finalTitle.isEmpty ? "未命名集合" : finalTitle,
                promptIds: selectedIds
            )
            store.addCollection(collection)
        }
        onDismiss()
    }
}

// MARK: - Left Panel Row

private struct LeftPanelPromptRow: View {
    @EnvironmentObject var theme: ThemeManager
    let prompt: Prompt
    let isAdded: Bool
    let onAdd: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isAdded ? "checkmark.circle.fill" : "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(isAdded ? Color.orange.opacity(0.8) : theme.textTertiary)

            Text(prompt.title)
                .font(.system(size: 12))
                .foregroundStyle(isAdded ? theme.textSecondary : theme.textPrimary)
                .lineLimit(1)

            Spacer()

            if isHovered {
                Button(action: onAdd) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(isAdded ? theme.textTertiary : theme.accentSubtle)
                        .frame(width: 20, height: 20)
                        .background(isAdded ? Color.clear : theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .disabled(isAdded)
                .transition(.opacity.animation(.easeInOut(duration: 0.1)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? theme.surfaceBg : Color.clear)
        )
        .opacity(isAdded ? 0.55 : 1.0)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Right Panel Row

private struct RightPanelPromptRow: View {
    @EnvironmentObject var theme: ThemeManager
    let prompt: Prompt
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)

            Image(systemName: "doc.text.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.orange.opacity(0.7))

            Text(prompt.title)
                .font(.system(size: 12))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Spacer()

            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 18, height: 18)
                        .background(theme.surfaceBg)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .transition(.opacity.animation(.easeInOut(duration: 0.1)))
            }
        }
        .padding(.vertical, 3)
        .onHover { isHovered = $0 }
    }
}
