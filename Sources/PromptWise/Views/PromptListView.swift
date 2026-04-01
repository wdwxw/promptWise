import SwiftUI

// MARK: - List View

struct PromptListView: View {
    let prompts: [Prompt]
    @ObservedObject var store: PromptStore
    @Binding var copiedPromptId: UUID?
    let onEdit: (Prompt) -> Void
    let onCopy: (Prompt) -> Void

    @State private var draggingPrompt: Prompt?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(prompts) { prompt in
                    PromptRowView(
                        prompt: prompt,
                        isCopied: copiedPromptId == prompt.id,
                        onCopy: { onCopy(prompt) },
                        onEdit: { onEdit(prompt) },
                        onDelete: { store.deletePrompt(id: prompt.id) },
                        onDragStarted: { p in draggingPrompt = p },
                        onDragEnded: { draggingPrompt = nil }
                    )
                    .onDrop(of: [.text], delegate: PromptDropDelegate(
                        targetPrompt: prompt,
                        store: store,
                        draggingPrompt: $draggingPrompt
                    ))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Row View

struct PromptRowView: View {
    let prompt: Prompt
    let isCopied: Bool
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDragStarted: (Prompt) -> Void
    let onDragEnded: () -> Void

    @State private var isHovered = false
    @State private var showPopover = false

    var body: some View {
        ZStack {
            DraggablePromptOverlay(
                prompt: prompt,
                onDragStarted: onDragStarted,
                onDragEnded: onDragEnded,
                onTap: onCopy
            )

            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)

                Text(prompt.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                if isCopied {
                    Text("已复制")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .allowsHitTesting(false)

            HStack {
                Spacer()
                if isHovered && !isCopied {
                    HStack(spacing: 2) {
                        rowActionButton(icon: "pencil", action: onEdit)
                        rowActionButton(icon: "trash", color: .red.opacity(0.6), action: onDelete)
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Theme.surfaceBg : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
            if hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if isHovered { showPopover = true }
                }
            } else {
                showPopover = false
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            promptPreview
        }
    }

    private func rowActionButton(icon: String, color: Color = Theme.textTertiary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(Theme.border)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private var promptPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prompt.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Rectangle().fill(Theme.border).frame(height: 1)

            if let attributed = try? AttributedString(markdown: prompt.content) {
                Text(attributed)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
            } else {
                Text(prompt.content)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(minWidth: 200, maxWidth: 320, maxHeight: 280)
        .background(Theme.panelBg)
    }
}

// MARK: - Grid View

struct PromptGridView: View {
    let prompts: [Prompt]
    @ObservedObject var store: PromptStore
    @Binding var copiedPromptId: UUID?
    let onEdit: (Prompt) -> Void
    let onCopy: (Prompt) -> Void

    @State private var draggingPrompt: Prompt?

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 6)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(prompts) { prompt in
                    PromptGridItemView(
                        prompt: prompt,
                        isCopied: copiedPromptId == prompt.id,
                        onCopy: { onCopy(prompt) },
                        onEdit: { onEdit(prompt) },
                        onDelete: { store.deletePrompt(id: prompt.id) },
                        onDragStarted: { p in draggingPrompt = p },
                        onDragEnded: { draggingPrompt = nil }
                    )
                    .onDrop(of: [.text], delegate: PromptDropDelegate(
                        targetPrompt: prompt,
                        store: store,
                        draggingPrompt: $draggingPrompt
                    ))
                }
            }
            .padding(10)
        }
    }
}

// MARK: - Grid Item View

struct PromptGridItemView: View {
    let prompt: Prompt
    let isCopied: Bool
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDragStarted: (Prompt) -> Void
    let onDragEnded: () -> Void

    @State private var isHovered = false
    @State private var showPopover = false

    var body: some View {
        ZStack {
            DraggablePromptOverlay(
                prompt: prompt,
                onDragStarted: onDragStarted,
                onDragEnded: onDragEnded,
                onTap: onCopy
            )

            VStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 4)

                Text(prompt.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if isCopied {
                    Text("已复制")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.green.opacity(0.8))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(8)
            .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    if isHovered {
                        HStack(spacing: 1) {
                            gridActionButton(icon: "pencil", action: onEdit)
                            gridActionButton(icon: "trash", color: .red.opacity(0.6), action: onDelete)
                        }
                        .padding(3)
                        .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                    }
                }
                Spacer()
            }
        }
        .frame(minHeight: 64)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Theme.surfaceBg : Theme.panelBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isHovered ? Theme.textTertiary.opacity(0.3) : Theme.border, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
            if hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if isHovered { showPopover = true }
                }
            } else {
                showPopover = false
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            gridPreview
        }
    }

    private func gridActionButton(icon: String, color: Color = Theme.textTertiary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .background(Theme.border)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }

    private var gridPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prompt.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Rectangle().fill(Theme.border).frame(height: 1)

            if let attributed = try? AttributedString(markdown: prompt.content) {
                Text(attributed)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
            } else {
                Text(prompt.content)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(minWidth: 200, maxWidth: 320, maxHeight: 280)
        .background(Theme.panelBg)
    }
}

// MARK: - Drop Delegate

struct PromptDropDelegate: DropDelegate {
    let targetPrompt: Prompt
    @ObservedObject var store: PromptStore
    @Binding var draggingPrompt: Prompt?

    func performDrop(info: DropInfo) -> Bool {
        draggingPrompt = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingPrompt,
              dragging.id != targetPrompt.id,
              let targetIndex = store.prompts.firstIndex(where: { $0.id == targetPrompt.id })
        else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            store.movePrompt(id: dragging.id, toIndex: targetIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
