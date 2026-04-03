import SwiftUI

// MARK: - 集合管理（查看所有集合 + 导航到创建/编辑）

struct PromptCollectionManagerView: View {
    @EnvironmentObject var theme: ThemeManager
    @ObservedObject var store: PromptStore

    /// nil = 列表视图，non-nil = 创建/编辑指定集合（PromptCollection? 表示新建或编辑已有）
    @State private var editingCollection: CollectionEditState = .none

    enum CollectionEditState {
        case none
        case creating
        case editing(PromptCollection)
    }

    var onDismiss: () -> Void

    var body: some View {
        switch editingCollection {
        case .none:
            listView
        case .creating:
            PromptCollectionCreatorView(store: store, existingCollection: nil) {
                editingCollection = .none
            }
        case .editing(let collection):
            PromptCollectionCreatorView(store: store, existingCollection: collection) {
                editingCollection = .none
            }
        }
    }

    // MARK: - Collection List

    private var listView: some View {
        VStack(spacing: 0) {
            headerBar
            divider

            if store.collections.isEmpty {
                emptyState
            } else {
                collectionList
            }
        }
        .frame(minWidth: 360, minHeight: 300)
        .background(theme.panelBg)
        .environment(\.colorScheme, theme.mode == .dark ? .dark : .light)
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)

            Text("提示语集合")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            if !store.collections.isEmpty {
                Text("\(store.collections.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.iconOnSurface)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(theme.surfaceBg)
                    .clipShape(Capsule())
            }

            Spacer()

            Button(action: { editingCollection = .creating }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                    Text("新建集合")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
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
        .background(WindowDragArea())
    }

    private var divider: some View {
        Rectangle().fill(theme.border).frame(height: 1)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "rectangle.stack")
                .font(.system(size: 36))
                .foregroundStyle(theme.textTertiary.opacity(0.5))
            Text("还没有提示语集合")
                .font(.system(size: 13))
                .foregroundStyle(theme.textTertiary)
            Button(action: { editingCollection = .creating }) {
                Text("＋ 创建第一个集合")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var collectionList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(store.collections) { collection in
                    CollectionManagerRow(
                        collection: collection,
                        promptCount: store.prompts(in: collection).count,
                        onEdit: { editingCollection = .editing(collection) },
                        onDelete: { store.deleteCollection(id: collection.id) }
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Collection Manager Row

private struct CollectionManagerRow: View {
    @EnvironmentObject var theme: ThemeManager
    let collection: PromptCollection
    let promptCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text("\(promptCount) 条提示语")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.iconOnSurface)
                            .frame(width: 22, height: 22)
                            .background(theme.surfaceBg)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.7))
                            .frame(width: 22, height: 22)
                            .background(theme.surfaceBg)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.1)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? theme.surfaceBg : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(theme.border, lineWidth: isHovered ? 1 : 0)
        )
        .onHover { isHovered = $0 }
        .confirmationDialog(
            "删除「\(collection.title)」？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) { onDelete() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销。")
        }
    }
}
