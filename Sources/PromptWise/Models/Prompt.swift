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

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        categoryId: UUID? = nil,
        isStarred: Bool = false,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.categoryId = categoryId
        self.isStarred = isStarred
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, content, categoryId, isStarred, order, createdAt, updatedAt
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
    }

    var plainTextContent: String {
        content
            .replacingOccurrences(of: #"#{1,6}\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\*{1,2}([^*]+)\*{1,2}"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
    }
}
