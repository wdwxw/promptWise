import SwiftUI

struct QuickAccessView: View {
    @ObservedObject var store: PromptStore
    @EnvironmentObject private var theme: ThemeManager
    var onHoverChanged: ((Bool) -> Void)?

    @State private var copiedId: UUID?
    @State private var copiedCollectionId: UUID?
    /// 当前 hover 集合包含的提示语 ID（用于高亮快捷列表）
    @State private var highlightedPromptIds: Set<UUID> = []
    private let maxPerColumn = 10

    private var recentPrompts: [Prompt] {
        let filtered = store.prompts(for: theme.quickAccessCategoryId)
        return Array(filtered.prefix(theme.quickAccessItemCount))
    }

    private var columns: [[Prompt]] {
        let items = recentPrompts
        guard !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: maxPerColumn).map {
            Array(items[$0..<min($0 + maxPerColumn, items.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 提示语集合列表（在快捷列表之前）
            if !store.collections.isEmpty {
                collectionsSection
                if !recentPrompts.isEmpty {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                }
            }

            // 快捷提示语列表（带序号，支持集合 hover 高亮）
            if !recentPrompts.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { colIndex, column in
                        VStack(spacing: 3) {
                            ForEach(Array(column.enumerated()), id: \.element.id) { rowIndex, prompt in
                                let globalIndex = colIndex * maxPerColumn + rowIndex + 1
                                QuickAccessItemView(
                                    prompt: prompt,
                                    index: globalIndex,
                                    isCopied: copiedId == prompt.id,
                                    isHighlightedByCollection: highlightedPromptIds.contains(prompt.id),
                                    onCopy: { copyPrompt(prompt) },
                                    onDragStarted: { store.recordUsage(id: prompt.id) }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(4)
        .onHover { hovering in
            onHoverChanged?(hovering)
        }
    }

    // MARK: - Collections Section

    /// 每行显示的集合数 = 快捷提示语的列数（保持与提示语宽度一致）
    private var collectionsPerRow: Int {
        max(1, columns.count)
    }

    /// 将集合按行分组
    private var collectionRows: [[PromptCollection]] {
        let perRow = collectionsPerRow
        return stride(from: 0, to: store.collections.count, by: perRow).map {
            Array(store.collections[$0..<min($0 + perRow, store.collections.count)])
        }
    }

    private var collectionsSection: some View {
        VStack(spacing: 3) {
            ForEach(Array(collectionRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 4) {
                    ForEach(row) { collection in
                        CollectionQuickItemView(
                            collection: collection,
                            allPrompts: store.prompts,
                            isCopied: copiedCollectionId == collection.id,
                            onCopy: { copyCollection(collection) },
                            onHoverChanged: { hovering in
                                if hovering {
                                    let ids = Set(store.prompts(in: collection).map(\.id))
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        highlightedPromptIds = ids
                                    }
                                } else {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        highlightedPromptIds = []
                                    }
                                }
                            }
                        )
                    }
                    // 用等宽占位视图填充空位，保证每行宽度分配一致
                    ForEach(0..<(collectionsPerRow - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Copy Actions

    private func copyPrompt(_ prompt: Prompt) {
        store.recordUsage(id: prompt.id)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)

        withAnimation(.easeInOut(duration: 0.2)) {
            copiedId = prompt.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                if copiedId == prompt.id { copiedId = nil }
            }
        }
    }

    private func copyCollection(_ collection: PromptCollection) {
        let prompts = store.prompts(in: collection)
        let combined = prompts.map(\.content).joined()
        guard !combined.isEmpty else { return }

        // 集合内每条提示语都记录一次使用
        for prompt in prompts {
            store.recordUsage(id: prompt.id)
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(combined, forType: .string)

        withAnimation(.easeInOut(duration: 0.2)) {
            copiedCollectionId = collection.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                if copiedCollectionId == collection.id { copiedCollectionId = nil }
            }
        }
    }
}

// MARK: - Collection Quick Item（橙色胶囊）

private struct CollectionQuickItemView: View {
    let collection: PromptCollection
    let allPrompts: [Prompt]
    let isCopied: Bool
    let onCopy: () -> Void
    var onHoverChanged: ((Bool) -> Void)? = nil

    @State private var isHovered = false
    @EnvironmentObject private var theme: ThemeManager

    private var isDark: Bool { theme.mode == .dark }

    private var includedPrompts: [Prompt] {
        collection.promptIds.compactMap { id in allPrompts.first { $0.id == id } }
    }

    private var backgroundColor: Color {
        if isHovered {
            return Color.orange.opacity(0.72)
        }
        return isDark
            ? Color.orange.opacity(0.28)
            : Color.orange.opacity(0.18)
    }

    private var titleColor: Color {
        if isHovered { return .white }
        return isDark ? Color.orange.opacity(0.9) : Color.orange.opacity(0.85)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 10))
                .foregroundStyle(isHovered ? .white.opacity(0.9) : Color.orange.opacity(0.75))

            Text(collection.title)
                .font(.system(size: 11))
                .foregroundStyle(titleColor)
                .lineLimit(1)

            Spacer(minLength: 0)

            if isCopied {
                Text("已复制")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .shadow(color: Color.orange.opacity(isDark ? 0.12 : 0.08), radius: 2, y: 1)
        .offset(x: isHovered ? 4 : 0)
        .contentShape(Capsule())
        .onTapGesture { onCopy() }
        .onDrag {
            let combined = includedPrompts.map(\.content).joined()
            return NSItemProvider(object: combined as NSString)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
            onHoverChanged?(hovering)
        }
    }

}

// MARK: - Single Capsule Item

private struct QuickAccessItemView: View {
    let prompt: Prompt
    let index: Int
    let isCopied: Bool
    /// 是否被某个集合的 hover 所高亮
    var isHighlightedByCollection: Bool = false
    let onCopy: () -> Void
    var onDragStarted: (() -> Void)? = nil

    @State private var isHovered = false
    @EnvironmentObject private var theme: ThemeManager

    private var isDark: Bool { theme.mode == .dark }

    private var backgroundColor: Color {
        if isHovered {
            return Color(nsColor: NSColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 0.5))
        }
        if isHighlightedByCollection {
            return isDark
                ? Color.orange.opacity(0.22)
                : Color.orange.opacity(0.15)
        }
        return isDark
            ? Color.black.opacity(0.65)
            : Color.white.opacity(0.65)
    }

    private var foregroundColor: Color {
        if isHovered && !isDark { return .white }
        if isHighlightedByCollection {
            return isDark ? Color.orange.opacity(0.9) : Color.orange.opacity(0.8)
        }
        return isDark ? .white.opacity(0.8) : theme.textPrimary
    }

    private var indexColor: Color {
        if isHovered {
            return isDark ? .white.opacity(0.5) : .white.opacity(0.7)
        }
        if isHighlightedByCollection {
            return Color.orange.opacity(0.6)
        }
        return isDark ? .white.opacity(0.25) : theme.textTertiary
    }

    var body: some View {
        HStack(spacing: 6) {
            // 序号前缀
            Text("\(index)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(indexColor)
                .frame(width: 14, alignment: .center)

            Text(prompt.title)
                .font(.system(size: 11))
                .foregroundStyle(foregroundColor)
                .lineLimit(1)

            Spacer(minLength: 0)

            if isCopied {
                Text("已复制")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.green.opacity(0.8))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: 180)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .shadow(
            color: isHighlightedByCollection
                ? Color.orange.opacity(isDark ? 0.25 : 0.15)
                : .black.opacity(isDark ? 0.15 : 0.08),
            radius: isHighlightedByCollection ? 3 : 2,
            y: 1
        )
        .offset(x: isHovered ? 4 : isHighlightedByCollection ? 2 : 0)
        .animation(.easeInOut(duration: 0.15), value: isHighlightedByCollection)
        .contentShape(Capsule())
        .onTapGesture { onCopy() }
        .onDrag {
            onDragStarted?()
            return NSItemProvider(object: prompt.content as NSString)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
