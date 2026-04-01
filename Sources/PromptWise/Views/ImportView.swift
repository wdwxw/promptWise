import SwiftUI

struct ImportView: View {
    @ObservedObject var store: PromptStore
    @Environment(\.dismiss) private var dismiss

    @State private var inputText = ""
    @State private var importedCount: Int?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            instructions
            editor
            Divider()
            footer
        }
        .frame(width: 520, height: 540)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("批量导入提示语")
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

    // MARK: - Format Instructions

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("支持两种格式")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Markdown 格式")
                        .font(.system(size: 11, weight: .semibold))
                    Text("## 标题\n内容...\n\n## 标题2\n内容...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("JSON 格式")
                        .font(.system(size: 11, weight: .semibold))
                    Text("[{\"title\":\"标题\",\n  \"content\":\"内容\"}]")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Text Editor

    private var editor: some View {
        TextEditor(text: $inputText)
            .font(.system(size: 13, design: .monospaced))
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
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let count = importedCount {
                Label("已导入 \(count) 条提示语", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            }

            Spacer()

            Button("取消") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button("导入") { performImport() }
                .keyboardShortcut(.defaultAction)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
    }

    private func performImport() {
        let count = store.importFromText(inputText)
        withAnimation { importedCount = count }
        if count > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        }
    }
}
