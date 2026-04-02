import SwiftUI

struct PromptEditView: View {
    @ObservedObject var store: PromptStore
    let prompt: Prompt?
    let defaultCategoryId: UUID?
    var onDismiss: (() -> Void)? // 可选的 dismiss 回调，用于窗口模式

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var categoryId: UUID?
    @State private var showPreview = false
    @State private var showingDuplicateAlert = false

    private var isEditing: Bool { prompt != nil }

    /// Token 估算：CJK 汉字约 1 字 ≈ 1 Token，其他字符约 4 字 ≈ 1 Token
    private var tokenEstimate: Int {
        guard !content.isEmpty else { return 0 }
        let cjkCount = content.unicodeScalars.filter {
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||  // CJK 统一汉字
            ($0.value >= 0x3400 && $0.value <= 0x4DBF) ||  // CJK 扩展A
            ($0.value >= 0x20000 && $0.value <= 0x2A6DF)   // CJK 扩展B
        }.count
        let otherCount = content.count - cjkCount
        return cjkCount + max(0, Int(ceil(Double(otherCount) / 4.0)))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 480, height: 520)
        .onAppear {
            if let prompt {
                title = prompt.title
                content = prompt.content
                categoryId = prompt.categoryId
            } else {
                categoryId = defaultCategoryId
            }
        }
        .alert("标题已存在", isPresented: $showingDuplicateAlert) {
            Button("取消", role: .cancel) {}
            Button("覆盖", role: .destructive) { commitSave(overwrite: true) }
        } message: {
            Text("提示语「\(title.trimmingCharacters(in: .whitespaces))」已存在，是否用当前内容覆盖？")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(isEditing ? "编辑提示语" : "新增提示语")
                .font(.headline)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Form

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("标题")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("输入提示语标题", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("分类")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Picker("分类", selection: $categoryId) {
                        Text("未分类").tag(UUID?.none)
                        ForEach(store.categories) { category in
                            Label(category.name, systemImage: category.icon)
                                .tag(Optional(category.id))
                        }
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("内容")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("支持 Markdown")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        if !content.isEmpty {
                            Text("\(content.count) 字 · ~\(tokenEstimate) Token")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        Toggle("预览", isOn: $showPreview)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }

                    if showPreview {
                        previewContent
                    } else {
                        TextEditor(text: $content)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(16)
        }
    }

    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let attributed = try? AttributedString(markdown: content) {
                    Text(attributed)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(content)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(8)
        }
        .frame(minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("取消") { handleDismiss() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            Text("⌘↩")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.trailing, 4)

            Button(isEditing ? "保存" : "添加") {
                savePrompt()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

            // ⌘↩ 快速提交：零尺寸隐藏按钮，仅绑定快捷键
            Button("") { savePrompt() }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(0)
                .frame(width: 0, height: 0)
        }
        .padding(16)
    }

    private func handleDismiss() {
        onDismiss?()
        dismiss()
    }

    private func savePrompt() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        // 新建时检测标题是否重复
        if !isEditing, store.findPrompt(byTitle: trimmedTitle) != nil {
            showingDuplicateAlert = true
            return
        }

        commitSave()
    }

    private func commitSave(overwrite: Bool = false) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        if var existing = prompt {
            existing.title = trimmedTitle
            existing.content = content
            existing.categoryId = categoryId
            store.updatePrompt(existing)
        } else if overwrite, let existingPrompt = store.findPrompt(byTitle: trimmedTitle) {
            var updated = existingPrompt
            updated.title = trimmedTitle
            updated.content = content
            updated.categoryId = categoryId
            store.updatePrompt(updated)
        } else {
            store.addPrompt(Prompt(title: trimmedTitle, content: content, categoryId: categoryId))
        }
        handleDismiss()
    }
}
