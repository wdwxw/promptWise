import Foundation

struct Category: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var icon: String
    var order: Int

    init(
        id: UUID = UUID(),
        name: String = "",
        icon: String = "folder",
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.order = order
    }
}
