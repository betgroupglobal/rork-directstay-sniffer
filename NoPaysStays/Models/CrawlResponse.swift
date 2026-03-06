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

nonisolated struct AirbnbSearchRequest: Codable, Sendable {
    let location: String
    var check_in: String?
    var check_out: String?
    var guests: Int?
    var min_bedrooms: Int?
    var min_bathrooms: Int?
    var pet_friendly: Bool?
    var price_min: Int?
    var price_max: Int?
    var max_results: Int?
}

nonisolated struct AirbnbSearchResponse: Codable, Sendable {
    let results: [AirbnbListing]
    let source: String
    let total: Int
}

nonisolated struct AirbnbListing: Codable, Identifiable, Sendable, Hashable {
    let id: String?
    let name: String?
    let url: String?
    let price_per_night: Double?
    let total_price: Double?
    let currency: String?
    let rating: Double?
    let reviews_count: Int?
    let room_type: String?
    let bedrooms: Int?
    let bathrooms: Double?
    let beds: Int?
    let guests: Int?
    let lat: Double?
    let lng: Double?
    let city: String?
    let superhost: Bool?
    let images: [String]?
    let amenities: [String]?

    var listingID: String {
        id ?? url ?? UUID().uuidString
    }

    nonisolated static func == (lhs: AirbnbListing, rhs: AirbnbListing) -> Bool {
        lhs.listingID == rhs.listingID
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(listingID)
    }
}
