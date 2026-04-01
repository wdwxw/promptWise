import Foundation
import SwiftUI

struct AppData: Codable {
    var prompts: [Prompt]
    var categories: [Category]
}

@MainActor
final class PromptStore: ObservableObject {
    @Published var prompts: [Prompt] = []
    @Published var categories: [Category] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("PromptWise", isDirectory: true)

        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.fileURL = appSupport.appendingPathComponent("data.json")
        load()
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let appData = try decoder.decode(AppData.self, from: data)
            self.prompts = appData.prompts.sorted { $0.order < $1.order }
            self.categories = appData.categories.sorted { $0.order < $1.order }
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    func save() {
        do {
            let appData = AppData(prompts: prompts, categories: categories)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(appData)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save data: \(error)")
        }
    }

    // MARK: - Prompts

    func addPrompt(_ prompt: Prompt) {
        var newPrompt = prompt
        newPrompt.order = (prompts.map(\.order).max() ?? -1) + 1
        prompts.append(newPrompt)
        save()
    }

    func updatePrompt(_ prompt: Prompt) {
        guard let index = prompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        var updated = prompt
        updated.updatedAt = Date()
        prompts[index] = updated
        save()
    }

    func deletePrompt(id: UUID) {
        prompts.removeAll { $0.id == id }
        reindexPrompts()
        save()
    }

    func toggleStar(id: UUID) {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[index].isStarred.toggle()
        prompts[index].updatedAt = Date()
        if prompts[index].isStarred {
            let prompt = prompts.remove(at: index)
            prompts.insert(prompt, at: 0)
        }
        reindexPrompts()
        save()
    }

    func movePrompt(from source: IndexSet, to destination: Int) {
        prompts.move(fromOffsets: source, toOffset: destination)
        reindexPrompts()
        save()
    }

    func movePrompt(id: UUID, toIndex destination: Int) {
        guard let sourceIndex = prompts.firstIndex(where: { $0.id == id }) else { return }
        let prompt = prompts.remove(at: sourceIndex)
        let safeDestination = min(destination, prompts.count)
        prompts.insert(prompt, at: safeDestination)
        reindexPrompts()
        save()
    }

    func restoreOrder(_ ids: [UUID]) {
        let lookup = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, $0) })
        var ordered: [Prompt] = ids.compactMap { lookup[$0] }
        let restored = Set(ordered.map(\.id))
        ordered += prompts.filter { !restored.contains($0.id) }
        prompts = ordered
        reindexPrompts()
        save()
    }

    private func reindexPrompts() {
        for i in prompts.indices {
            prompts[i].order = i
        }
    }

    func prompts(for categoryId: UUID?) -> [Prompt] {
        if let categoryId {
            return prompts.filter { $0.categoryId == categoryId }
        }
        return prompts
    }

    func searchPrompts(query: String, categoryId: UUID?) -> [Prompt] {
        let filtered = prompts(for: categoryId)
        guard !query.isEmpty else { return filtered }
        let lowered = query.lowercased()
        return filtered.filter {
            $0.title.lowercased().contains(lowered) ||
            $0.content.lowercased().contains(lowered)
        }
    }

    // MARK: - Export / Import

    func exportData() -> Data? {
        let appData = AppData(prompts: prompts, categories: categories)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(appData)
    }

    func importFromText(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            return importFromJSON(trimmed)
        }
        return importFromMarkdown(trimmed)
    }

    private func importFromJSON(_ text: String) -> Int {
        guard let data = text.data(using: .utf8) else { return 0 }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let appData = try? decoder.decode(AppData.self, from: data) {
            return importAppData(appData)
        }

        if let arr = try? decoder.decode([Prompt].self, from: data) {
            for var p in arr {
                p.id = UUID()
                p.categoryId = nil
                addPrompt(p)
            }
            return arr.count
        }

        struct SimplePrompt: Codable { let title: String; let content: String }
        if let arr = try? decoder.decode([SimplePrompt].self, from: data) {
            for sp in arr { addPrompt(Prompt(title: sp.title, content: sp.content)) }
            return arr.count
        }

        return 0
    }

    private func importAppData(_ appData: AppData) -> Int {
        var categoryMapping: [UUID: UUID] = [:]
        for imported in appData.categories {
            if let existing = categories.first(where: { $0.name == imported.name }) {
                categoryMapping[imported.id] = existing.id
            } else {
                let newCat = Category(name: imported.name, icon: imported.icon)
                addCategory(newCat)
                categoryMapping[imported.id] = newCat.id
            }
        }

        var count = 0
        for imported in appData.prompts {
            var p = Prompt(title: imported.title, content: imported.content)
            if let oldCatId = imported.categoryId {
                p.categoryId = categoryMapping[oldCatId]
            }
            addPrompt(p)
            count += 1
        }
        return count
    }

    private func importFromMarkdown(_ text: String) -> Int {
        let lines = text.components(separatedBy: "\n")
        var currentTitle: String?
        var currentContent: [String] = []
        var count = 0

        func saveCurrentPrompt() {
            guard let title = currentTitle, !title.isEmpty else { return }
            let content = currentContent.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            addPrompt(Prompt(title: title, content: content))
            count += 1
        }

        for line in lines {
            if line.hasPrefix("## ") {
                saveCurrentPrompt()
                currentTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentContent = []
            } else if currentTitle != nil {
                currentContent.append(line)
            }
        }
        saveCurrentPrompt()
        return count
    }

    // MARK: - Categories

    func addCategory(_ category: Category) {
        var newCategory = category
        newCategory.order = (categories.map(\.order).max() ?? -1) + 1
        categories.append(newCategory)
        save()
    }

    func updateCategory(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index] = category
        save()
    }

    func deleteCategory(id: UUID) {
        for i in prompts.indices where prompts[i].categoryId == id {
            prompts[i].categoryId = nil
        }
        categories.removeAll { $0.id == id }
        save()
    }

    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        for i in categories.indices {
            categories[i].order = i
        }
        save()
    }
}
