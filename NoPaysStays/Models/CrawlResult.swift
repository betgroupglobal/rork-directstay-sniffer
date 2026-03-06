import Foundation

nonisolated struct CrawlResult: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let url: String
    let snippet: String
    let sourcePlatform: String
    let category: PlatformCategory
    let feeIndicator: String
    let directBookingLikelihood: DirectBookingLikelihood
    let discoveredAt: Date
    let ownerContact: String?
    let priceHint: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        url: String,
        snippet: String,
        sourcePlatform: String,
        category: PlatformCategory,
        feeIndicator: String = "Varies",
        directBookingLikelihood: DirectBookingLikelihood = .medium,
        discoveredAt: Date = Date(),
        ownerContact: String? = nil,
        priceHint: String? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
        self.sourcePlatform = sourcePlatform
        self.category = category
        self.feeIndicator = feeIndicator
        self.directBookingLikelihood = directBookingLikelihood
        self.discoveredAt = discoveredAt
        self.ownerContact = ownerContact
        self.priceHint = priceHint
    }
}

nonisolated enum DirectBookingLikelihood: String, Sendable, Hashable, Comparable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }

    var icon: String {
        switch self {
        case .high: "checkmark.seal.fill"
        case .medium: "seal.fill"
        case .low: "questionmark.circle.fill"
        }
    }

    private var sortValue: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }

    nonisolated static func < (lhs: DirectBookingLikelihood, rhs: DirectBookingLikelihood) -> Bool {
        lhs.sortValue < rhs.sortValue
    }
}

nonisolated enum SpiderStatus: Sendable, Hashable {
    case idle
    case crawling(source: String, progress: Double)
    case analyzing
    case completed
    case failed(String)

    var isActive: Bool {
        switch self {
        case .crawling, .analyzing: true
        default: false
        }
    }

    var label: String {
        switch self {
        case .idle: "Ready"
        case .crawling(let source, _): "Crawling \(source)…"
        case .analyzing: "Analyzing results…"
        case .completed: "Hunt complete"
        case .failed(let msg): "Failed: \(msg)"
        }
    }
}
