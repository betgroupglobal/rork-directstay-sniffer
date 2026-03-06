import Foundation

nonisolated struct SearchCriteria: Codable, Identifiable, Sendable, Hashable {
    let id: String
    var location: String
    var checkIn: Date?
    var checkOut: Date?
    var guests: Int
    var bedrooms: Int
    var bathrooms: Int
    var isPetFriendly: Bool
    var isWholeHome: Bool
    var maxPricePerNight: Int?
    var radiusKm: Int
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        location: String = "",
        checkIn: Date? = nil,
        checkOut: Date? = nil,
        guests: Int = 2,
        bedrooms: Int = 1,
        bathrooms: Int = 1,
        isPetFriendly: Bool = false,
        isWholeHome: Bool = true,
        maxPricePerNight: Int? = nil,
        radiusKm: Int = 25,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.location = location
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.guests = guests
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.isPetFriendly = isPetFriendly
        self.isWholeHome = isWholeHome
        self.maxPricePerNight = maxPricePerNight
        self.radiusKm = radiusKm
        self.createdAt = createdAt
    }

    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if let checkIn, let checkOut {
            return "\(formatter.string(from: checkIn)) – \(formatter.string(from: checkOut))"
        } else if let checkIn {
            return "From \(formatter.string(from: checkIn))"
        }
        return "Flexible dates"
    }

    var summaryText: String {
        var parts: [String] = []
        parts.append("\(guests) guest\(guests == 1 ? "" : "s")")
        parts.append("\(bedrooms) bed\(bedrooms == 1 ? "" : "s")")
        parts.append("\(bathrooms) bath\(bathrooms == 1 ? "" : "s")")
        if isPetFriendly { parts.append("pets") }
        return parts.joined(separator: " · ")
    }
}
