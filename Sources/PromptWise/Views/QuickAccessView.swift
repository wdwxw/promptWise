import SwiftUI

struct QuickAccessView: View {
    @ObservedObject var store: PromptStore
    @EnvironmentObject private var theme: ThemeManager
    var onHoverChanged: ((Bool) -> Void)?

    @State private var copiedId: UUID?
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
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                VStack(spacing: 3) {
                    ForEach(column) { prompt in
                        QuickAccessItemView(
                            prompt: prompt,
                            isCopied: copiedId == prompt.id,
                            onCopy: { copyPrompt(prompt) }
                        )
                    }
                }
            }
        }
        .padding(4)
        .onHover { hovering in
            onHoverChanged?(hovering)
        }
    }

    private func copyPrompt(_ prompt: Prompt) {
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
}

// MARK: - Single Capsule Item

private struct QuickAccessItemView: View {
    let prompt: Prompt
    let isCopied: Bool
    let onCopy: () -> Void

    @State private var isHovered = false
    @EnvironmentObject private var theme: ThemeManager

    private var isDark: Bool { theme.mode == .dark }

    private var backgroundColor: Color {
        if isHovered {
            return Color(nsColor: NSColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 0.5))
        }
        return isDark
            ? Color.black.opacity(0.65)
            : Color.white.opacity(0.65)
    }

    private var foregroundColor: Color {
        if isHovered && !isDark {
            return .white
        }
        return isDark
            ? .white.opacity(0.8)
            : theme.textPrimary
    }

    private var iconColor: Color {
        if isHovered && !isDark {
            return .white.opacity(0.8)
        }
        return isDark
            ? .white.opacity(0.35)
            : theme.textSecondary
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(iconColor)

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
        .shadow(color: .black.opacity(isDark ? 0.15 : 0.08), radius: 2, y: 1)
        .offset(x: isHovered ? 4 : 0)
        .contentShape(Capsule())
        .onTapGesture { onCopy() }
        .onDrag {
            NSItemProvider(object: prompt.content as NSString)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
