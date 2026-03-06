import Foundation

nonisolated struct CrawlRequest: Codable, Sendable {
    let location: String
    var check_in: String?
    var check_out: String?
    var guests: Int?
    var bedrooms: Int?
    var bathrooms: Int?
    var pet_friendly: Bool?
    var whole_home: Bool?
    var max_results: Int?
}

nonisolated struct CrawlResponse: Codable, Sendable {
    let query: String
    let total: Int
    let results: [BookingHit]
}

nonisolated struct BookingHit: Codable, Identifiable, Sendable, Hashable {
    var id: String { booking_url }
    let booking_url: String
    let source: String
    let discovered_on: String
    let title: String
    let snippet: String
    let score: Double
    let matched_terms: [String]
}
