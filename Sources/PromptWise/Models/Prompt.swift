import Foundation

struct Prompt: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var content: String
    var categoryId: UUID?
    var order: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        categoryId: UUID? = nil,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.categoryId = categoryId
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var plainTextContent: String {
        content
            .replacingOccurrences(of: #"#{1,6}\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\*{1,2}([^*]+)\*{1,2}"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
    }
}
