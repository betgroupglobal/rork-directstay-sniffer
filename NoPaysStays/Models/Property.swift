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

    static func fromBookingHit(_ hit: BookingHit) -> Property {
        let urlHost = URL(string: hit.booking_url)?.host ?? hit.source
        let isDirectHit = hit.source.localizedCaseInsensitiveContains("direct")
            || hit.booking_url.contains("owner")
            || (!hit.booking_url.contains("airbnb") && !hit.booking_url.contains("booking.com") && !hit.booking_url.contains("stayz") && !hit.booking_url.contains("expedia"))

        let link = BookingLink(
            id: UUID().uuidString,
            platform: urlHost,
            url: hit.booking_url,
            pricePerNight: 0,
            totalPrice: 0,
            isDirectBooking: isDirectHit,
            feesIncluded: false
        )

        let strength: BookingStrength = isDirectHit ? .direct : .alternative

        return Property(
            id: hit.booking_url,
            title: hit.title.isEmpty ? urlHost : hit.title,
            subtitle: String(hit.snippet.prefix(120)),
            address: "",
            suburb: "",
            state: "",
            postcode: "",
            latitude: 0,
            longitude: 0,
            propertyType: .house,
            bedrooms: 0,
            bathrooms: 0,
            maxGuests: 0,
            isPetFriendly: false,
            amenities: hit.matched_terms,
            imageURLs: [],
            bookingLinks: [link],
            ownerContact: nil,
            bookingStrength: strength,
            otaPrice: 0,
            bestAlternativePrice: nil,
            discoveredAt: Date()
        )
    }

    static func fromAirbnbListing(_ listing: AirbnbListing) -> Property? {
        guard let url = listing.url, !url.isEmpty else { return nil }
        let name = listing.name ?? "Airbnb Listing"
        let pricePerNight = listing.price_per_night ?? 0

        let airbnbLink = BookingLink(
            id: UUID().uuidString,
            platform: "Airbnb",
            url: url,
            pricePerNight: pricePerNight,
            totalPrice: listing.total_price ?? 0,
            isDirectBooking: false,
            feesIncluded: true
        )

        let city = listing.city ?? ""
        let roomType = listing.room_type ?? "Entire home"
        let bedroomCount = listing.bedrooms ?? 0
        let bathroomCount = Int(listing.bathrooms ?? 0)
        let guestCount = listing.guests ?? 2
        let ratingStr = listing.rating.map { String(format: "%.1f", $0) } ?? ""
        let reviewStr = listing.reviews_count.map { "(\($0) reviews)" } ?? ""
        let subtitle = [roomType, ratingStr.isEmpty ? nil : "\(ratingStr) ★ \(reviewStr)"].compactMap { $0 }.joined(separator: " · ")

        let propType: PropertyType = {
            let rt = roomType.lowercased()
            if rt.contains("cabin") { return .cabin }
            if rt.contains("apartment") || rt.contains("condo") { return .apartment }
            if rt.contains("farm") { return .farmStay }
            if rt.contains("glamp") || rt.contains("tent") { return .glamping }
            return .house
        }()

        return Property(
            id: "airbnb-\(listing.listingID)",
            title: name,
            subtitle: subtitle,
            address: "",
            suburb: city,
            state: "",
            postcode: "",
            latitude: listing.lat ?? 0,
            longitude: listing.lng ?? 0,
            propertyType: propType,
            bedrooms: bedroomCount,
            bathrooms: bathroomCount,
            maxGuests: guestCount,
            isPetFriendly: false,
            amenities: listing.amenities ?? [],
            imageURLs: listing.images ?? [],
            bookingLinks: [airbnbLink],
            ownerContact: nil,
            bookingStrength: .mainstreamOnly,
            otaPrice: pricePerNight,
            bestAlternativePrice: nil,
            discoveredAt: Date()
        )
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
