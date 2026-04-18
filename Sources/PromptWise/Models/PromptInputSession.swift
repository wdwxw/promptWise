import Foundation

/// 优化版本
struct OptimizedVersion: Identifiable, Codable, Hashable {
    var id: UUID
    var index: Int                      // 序号（用于显示"提示语 1"、"提示语 2"）
    var content: String                 // 优化后的内容
    var modelConfigId: UUID             // 使用的模型配置 ID
    var modelConfigName: String         // 模型配置名称（快照）
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        index: Int,
        content: String,
        modelConfigId: UUID,
        modelConfigName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.index = index
        self.content = content
        self.modelConfigId = modelConfigId
        self.modelConfigName = modelConfigName
        self.createdAt = createdAt
    }
}

/// 输入会话状态
struct PromptInputSession: Codable {
    var originalContent: String         // 原始输入内容（"当前"）
    var versions: [OptimizedVersion]    // 优化版本列表
    var selectedVersionId: UUID?        // 当前选中的版本（nil 表示显示原始内容）
    var versionCounter: Int             // 版本计数器（用于生成序号）
    var lastUpdatedAt: Date
    
    init(
        originalContent: String = "",
        versions: [OptimizedVersion] = [],
        selectedVersionId: UUID? = nil,
        versionCounter: Int = 0,
        lastUpdatedAt: Date = Date()
    ) {
        self.originalContent = originalContent
        self.versions = versions
        self.selectedVersionId = selectedVersionId
        self.versionCounter = versionCounter
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    /// 当前显示的内容
    var currentContent: String {
        if let versionId = selectedVersionId,
           let version = versions.first(where: { $0.id == versionId }) {
            return version.content
        }
        return originalContent
    }
    
    /// 是否选中原始内容
    var isOriginalSelected: Bool {
        selectedVersionId == nil
    }
    
    /// 清除所有版本
    mutating func clearVersions() {
        versions.removeAll()
        selectedVersionId = nil
        versionCounter = 0
        lastUpdatedAt = Date()
    }
    
    /// 添加新版本
    mutating func addVersion(content: String, modelConfigId: UUID, modelConfigName: String) -> OptimizedVersion {
        versionCounter += 1
        let version = OptimizedVersion(
            index: versionCounter,
            content: content,
            modelConfigId: modelConfigId,
            modelConfigName: modelConfigName
        )
        versions.append(version)
        selectedVersionId = version.id
        lastUpdatedAt = Date()
        return version
    }
    
    /// 选择版本
    mutating func selectVersion(_ id: UUID?) {
        selectedVersionId = id
        lastUpdatedAt = Date()
    }
    
    /// 更新版本内容（用于流式输出）
    mutating func updateVersionContent(_ id: UUID, content: String) {
        if let index = versions.firstIndex(where: { $0.id == id }) {
            versions[index].content = content
            lastUpdatedAt = Date()
        }
    }
}
