import Foundation

nonisolated enum PlatformCategory: String, Codable, Sendable, CaseIterable {
    case directBooking
    case alternativePlatform
    case classifieds
    case searchEngine
    case socialMedia
    case tourismDirectory

    var label: String {
        switch self {
        case .directBooking: "Direct Booking"
        case .alternativePlatform: "Alternative Platforms"
        case .classifieds: "Classifieds & Marketplaces"
        case .searchEngine: "Deep Search Queries"
        case .socialMedia: "Social & Forums"
        case .tourismDirectory: "Tourism Directories"
        }
    }

    var icon: String {
        switch self {
        case .directBooking: "checkmark.seal.fill"
        case .alternativePlatform: "building.2.fill"
        case .classifieds: "newspaper.fill"
        case .searchEngine: "magnifyingglass"
        case .socialMedia: "bubble.left.and.bubble.right.fill"
        case .tourismDirectory: "map.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .directBooking: 0
        case .alternativePlatform: 1
        case .classifieds: 2
        case .searchEngine: 3
        case .socialMedia: 4
        case .tourismDirectory: 5
        }
    }
}

nonisolated struct PlatformSearch: Identifiable, Sendable, Hashable {
    let id: String
    let platformName: String
    let category: PlatformCategory
    let searchURL: URL
    let description: String
    let icon: String
    let feePercentage: String?

    init(
        id: String = UUID().uuidString,
        platformName: String,
        category: PlatformCategory,
        searchURL: URL,
        description: String,
        icon: String,
        feePercentage: String? = nil
    ) {
        self.id = id
        self.platformName = platformName
        self.category = category
        self.searchURL = searchURL
        self.description = description
        self.icon = icon
        self.feePercentage = feePercentage
    }
}

nonisolated struct SavedFind: Codable, Identifiable, Sendable, Hashable {
    let id: String
    var title: String
    var platform: String
    var url: String
    var notes: String
    var pricePerNight: Int?
    let savedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        platform: String,
        url: String,
        notes: String = "",
        pricePerNight: Int? = nil,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.platform = platform
        self.url = url
        self.notes = notes
        self.pricePerNight = pricePerNight
        self.savedAt = savedAt
    }
}
