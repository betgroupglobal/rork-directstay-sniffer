import Foundation

nonisolated struct PropertyAnalysis: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let url: String
    let platformName: String
    let location: String
    let analyzedAt: Date
    var propertyOfferings: String
    var businessPresence: String
    var reviewsSummary: String
    var paymentMethods: String
    var directBookingScore: Int
    var keyInsights: [String]

    init(
        id: String = UUID().uuidString,
        url: String,
        platformName: String,
        location: String,
        analyzedAt: Date = Date(),
        propertyOfferings: String = "",
        businessPresence: String = "",
        reviewsSummary: String = "",
        paymentMethods: String = "",
        directBookingScore: Int = 0,
        keyInsights: [String] = []
    ) {
        self.id = id
        self.url = url
        self.platformName = platformName
        self.location = location
        self.analyzedAt = analyzedAt
        self.propertyOfferings = propertyOfferings
        self.businessPresence = businessPresence
        self.reviewsSummary = reviewsSummary
        self.paymentMethods = paymentMethods
        self.directBookingScore = directBookingScore
        self.keyInsights = keyInsights
    }
}

nonisolated struct AIAnalysisResponse: Codable, Sendable {
    let propertyOfferings: String
    let businessPresence: String
    let reviewsSummary: String
    let paymentMethods: String
    let directBookingScore: Int
    let keyInsights: [String]
}

nonisolated struct ToolkitChatRequest: Codable, Sendable {
    let messages: [ToolkitMessage]
}

nonisolated struct ToolkitMessage: Codable, Sendable {
    let role: String
    let content: String
}

nonisolated struct ToolkitChatResponse: Codable, Sendable {
    let text: String?
    let content: String?
}
