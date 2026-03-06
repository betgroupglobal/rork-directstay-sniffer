import Foundation
import CoreLocation

nonisolated enum BookingStrength: String, Codable, Sendable, CaseIterable {
    case direct
    case alternative
    case mainstreamOnly

    var label: String {
        switch self {
        case .direct: "Direct Booking"
        case .alternative: "Alternative Platform"
        case .mainstreamOnly: "OTA Only"
        }
    }
}

nonisolated enum PropertyType: String, Codable, Sendable, CaseIterable {
    case house
    case apartment
    case cabin
    case glamping
    case farmStay
    case beachHouse

    var label: String {
        switch self {
        case .house: "House"
        case .apartment: "Apartment"
        case .cabin: "Cabin"
        case .glamping: "Glamping"
        case .farmStay: "Farm Stay"
        case .beachHouse: "Beach House"
        }
    }

    var icon: String {
        switch self {
        case .house: "house.fill"
        case .apartment: "building.2.fill"
        case .cabin: "tent.fill"
        case .glamping: "tent.2.fill"
        case .farmStay: "leaf.fill"
        case .beachHouse: "water.waves"
        }
    }
}

nonisolated struct BookingLink: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let platform: String
    let url: String
    let pricePerNight: Double
    let totalPrice: Double
    let isDirectBooking: Bool
    let feesIncluded: Bool
}

nonisolated struct OwnerContact: Codable, Sendable, Hashable {
    let name: String?
    let phone: String?
    let email: String?
    let website: String?
    let confidence: Double
}

nonisolated struct Property: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let address: String
    let suburb: String
    let state: String
    let postcode: String
    let latitude: Double
    let longitude: Double
    let propertyType: PropertyType
    let bedrooms: Int
    let bathrooms: Int
    let maxGuests: Int
    let isPetFriendly: Bool
    let amenities: [String]
    let imageURLs: [String]
    let bookingLinks: [BookingLink]
    let ownerContact: OwnerContact?
    let bookingStrength: BookingStrength
    let otaPrice: Double
    let bestAlternativePrice: Double?
    let discoveredAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var savingsPercentage: Int? {
        guard let altPrice = bestAlternativePrice, altPrice < otaPrice else { return nil }
        return Int(((otaPrice - altPrice) / otaPrice) * 100)
    }

    var savingsAmount: Double? {
        guard let altPrice = bestAlternativePrice, altPrice < otaPrice else { return nil }
        return otaPrice - altPrice
    }

    var displayPrice: Double {
        bestAlternativePrice ?? otaPrice
    }

    var cheapestLink: BookingLink? {
        bookingLinks.min(by: { $0.pricePerNight < $1.pricePerNight })
    }

    static func == (lhs: Property, rhs: Property) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
