import Foundation

nonisolated struct PropertyAlert: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let property: Property
    let savedSearchId: String
    let savedSearchName: String
    let savingsPercentage: Int?
    let discoveredAt: Date
    var isRead: Bool

    init(
        id: String = UUID().uuidString,
        property: Property,
        savedSearchId: String,
        savedSearchName: String,
        savingsPercentage: Int? = nil,
        discoveredAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.property = property
        self.savedSearchId = savedSearchId
        self.savedSearchName = savedSearchName
        self.savingsPercentage = savingsPercentage
        self.discoveredAt = discoveredAt
        self.isRead = isRead
    }
}
