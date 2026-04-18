import Foundation

/// 会话状态存储管理器
@MainActor
final class PromptInputSessionStore: ObservableObject {
    static let shared = PromptInputSessionStore()
    
    @Published var session: PromptInputSession
    
    private let fileURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("PromptWise", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        self.fileURL = appFolder.appendingPathComponent("session.json")
        self.session = PromptInputSession()
        
        load()
    }
    
    // MARK: - 持久化
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            session = try decoder.decode(PromptInputSession.self, from: data)
        } catch {
            print("[PromptInputSessionStore] Failed to load: \(error)")
        }
    }
    
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(session)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[PromptInputSessionStore] Failed to save: \(error)")
        }
    }
    
    // MARK: - 操作方法
    
    /// 更新原始内容
    func updateOriginalContent(_ content: String) {
        session.originalContent = content
        save()
    }
    
    /// 选择版本
    func selectVersion(_ id: UUID?) {
        session.selectVersion(id)
        save()
    }
    
    /// 添加新版本
    func addVersion(content: String, modelConfigId: UUID, modelConfigName: String) -> OptimizedVersion {
        let version = session.addVersion(content: content, modelConfigId: modelConfigId, modelConfigName: modelConfigName)
        save()
        return version
    }
    
    /// 更新版本内容（流式输出时使用）
    func updateVersionContent(_ id: UUID, content: String) {
        session.updateVersionContent(id, content: content)
        // 流式输出时不频繁保存，最后保存一次
    }
    
    /// 清除所有版本
    func clearVersions() {
        session.clearVersions()
        save()
    }
}
