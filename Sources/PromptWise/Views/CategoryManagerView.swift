import SwiftUI

struct CategoryManagerView: View {
    @ObservedObject var store: PromptStore
    @Environment(\.dismiss) private var dismiss

    @State private var newCategoryName = ""
    @State private var selectedIcon = "folder"
    @State private var editingCategory: Category?

    private let iconOptions = [
        "folder", "star", "bookmark", "tag",
        "laptopcomputer", "pencil", "text.bubble", "globe",
        "brain.head.profile", "lightbulb", "doc.text", "terminal",
        "paintbrush", "camera", "music.note", "gamecontroller"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            addCategorySection
            Divider()
            categoryList
            Divider()
            footer
        }
        .frame(width: 380, height: 460)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("分类管理")
                .font(.headline)
            Spacer()
        }
        .padding(16)
    }

    // MARK: - Add Category

    private var addCategorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("新增分类")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                iconPicker

                TextField("分类名称", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)

                Button(action: addCategory) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
    }

    private var iconPicker: some View {
        Menu {
            ForEach(iconOptions, id: \.self) { icon in
                Button(action: { selectedIcon = icon }) {
                    Label(icon, systemImage: icon)
                }
            }
        } label: {
            Image(systemName: selectedIcon)
                .font(.system(size: 16))
                .frame(width: 32, height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Category List

    private var categoryList: some View {
        Group {
            if store.categories.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                    Text("还没有分类")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(store.categories) { category in
                        CategoryRowView(
                            category: category,
                            promptCount: store.prompts(for: category.id).count,
                            onEdit: { editingCategory = category },
                            onDelete: { store.deleteCategory(id: category.id) }
                        )
                    }
                    .onMove { source, destination in
                        store.moveCategory(from: source, to: destination)
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditSheet(
                store: store,
                category: category,
                iconOptions: iconOptions
            )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("完成") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    // MARK: - Actions

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let category = Category(name: name, icon: selectedIcon)
        store.addCategory(category)
        newCategoryName = ""
        selectedIcon = "folder"
    }
}

// MARK: - Category Row

struct CategoryRowView: View {
    let category: Category
    let promptCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(category.name)
                .font(.system(size: 13, weight: .medium))

            Text("\(promptCount)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.05)))

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Category Edit Sheet

struct CategoryEditSheet: View {
    @ObservedObject var store: PromptStore
    let category: Category
    let iconOptions: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var icon: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("编辑分类")
                .font(.headline)

            HStack(spacing: 8) {
                Menu {
                    ForEach(iconOptions, id: \.self) { opt in
                        Button(action: { icon = opt }) {
                            Label(opt, systemImage: opt)
                        }
                    }
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .frame(width: 32, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                TextField("分类名称", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    var updated = category
                    updated.name = name.trimmingCharacters(in: .whitespaces)
                    updated.icon = icon
                    store.updateCategory(updated)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            name = category.name
            icon = category.icon
        }
    }
}
