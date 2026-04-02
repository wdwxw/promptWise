import Foundation

struct Prompt: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var content: String
    var categoryId: UUID?
    var isStarred: Bool
    var order: Int
    var createdAt: Date
    var updatedAt: Date
    /// 累计使用次数（复制 + 拖拽）
    var usageCount: Int
    /// 最近 30 天的使用时间戳（用于计算近 7 天使用数）
    var recentUsages: [Date]

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        categoryId: UUID? = nil,
        isStarred: Bool = false,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        usageCount: Int = 0,
        recentUsages: [Date] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.categoryId = categoryId
        self.isStarred = isStarred
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.usageCount = usageCount
        self.recentUsages = recentUsages
    }

    enum CodingKeys: String, CodingKey {
        case id, title, content, categoryId, isStarred, order, createdAt, updatedAt
        case usageCount, recentUsages
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        content = try c.decode(String.self, forKey: .content)
        categoryId = try c.decodeIfPresent(UUID.self, forKey: .categoryId)
        isStarred = try c.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false
        order = try c.decode(Int.self, forKey: .order)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        usageCount = try c.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        recentUsages = try c.decodeIfPresent([Date].self, forKey: .recentUsages) ?? []
    }

    var plainTextContent: String {
        content
            .replacingOccurrences(of: #"#{1,6}\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\*{1,2}([^*]+)\*{1,2}"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
    }
}
