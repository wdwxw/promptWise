import Foundation

/// 模型配置存储管理器
@MainActor
final class AIModelConfigStore: ObservableObject {
    static let shared = AIModelConfigStore()
    
    @Published var configs: [AIModelConfig] = []
    @Published var selectedConfigId: UUID?
    
    private let fileURL: URL
    private let selectedIdKey = "selectedModelConfigId"
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("PromptWise", isDirectory: true)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        self.fileURL = appFolder.appendingPathComponent("models.json")
        
        load()
        loadSelectedId()
        
        // 如果没有配置，创建默认配置
        if configs.isEmpty {
            let defaultConfig = AIModelConfig.defaultOllama()
            configs.append(defaultConfig)
            selectedConfigId = defaultConfig.id
            save()
            saveSelectedId()
        }
    }
    
    // MARK: - 持久化
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            configs = try decoder.decode([AIModelConfig].self, from: data)
            configs.sort { $0.order < $1.order }
        } catch {
            print("[AIModelConfigStore] Failed to load: \(error)")
        }
    }
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[AIModelConfigStore] Failed to save: \(error)")
        }
    }
    
    private func loadSelectedId() {
        if let idString = UserDefaults.standard.string(forKey: selectedIdKey),
           let id = UUID(uuidString: idString) {
            selectedConfigId = id
        } else if let first = configs.first {
            selectedConfigId = first.id
        }
    }
    
    private func saveSelectedId() {
        if let id = selectedConfigId {
            UserDefaults.standard.set(id.uuidString, forKey: selectedIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedIdKey)
        }
    }
    
    // MARK: - CRUD
    
    /// 获取当前选中的配置
    var selectedConfig: AIModelConfig? {
        configs.first { $0.id == selectedConfigId }
    }
    
    /// 添加配置
    func addConfig(_ config: AIModelConfig) {
        var newConfig = config
        newConfig.order = configs.count
        configs.append(newConfig)
        save()
    }
    
    /// 更新配置
    func updateConfig(_ config: AIModelConfig) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            var updated = config
            updated.updatedAt = Date()
            configs[index] = updated
            save()
        }
    }
    
    /// 删除配置
    func deleteConfig(id: UUID) {
        configs.removeAll { $0.id == id }
        // 如果删除的是当前选中的，切换到第一个
        if selectedConfigId == id {
            selectedConfigId = configs.first?.id
            saveSelectedId()
        }
        save()
    }
    
    /// 选择配置
    func selectConfig(id: UUID) {
        selectedConfigId = id
        saveSelectedId()
    }
    
    /// 重新排序
    func moveConfig(from source: IndexSet, to destination: Int) {
        configs.move(fromOffsets: source, toOffset: destination)
        for (index, _) in configs.enumerated() {
            configs[index].order = index
        }
        save()
    }
}
