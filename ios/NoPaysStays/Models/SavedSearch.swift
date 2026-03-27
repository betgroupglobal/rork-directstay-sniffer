import Foundation

nonisolated struct SavedSearch: Codable, Identifiable, Sendable, Hashable {
    let id: String
    var locationName: String
    var latitude: Double
    var longitude: Double
    var radiusKm: Double
    var checkIn: Date?
    var checkOut: Date?
    var guests: Int
    var isPetFriendly: Bool
    var directBookingOnly: Bool
    var propertyTypes: [PropertyType]
    var notificationsEnabled: Bool
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        locationName: String,
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 50,
        checkIn: Date? = nil,
        checkOut: Date? = nil,
        guests: Int = 2,
        isPetFriendly: Bool = false,
        directBookingOnly: Bool = false,
        propertyTypes: [PropertyType] = [],
        notificationsEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.radiusKm = radiusKm
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.guests = guests
        self.isPetFriendly = isPetFriendly
        self.directBookingOnly = directBookingOnly
        self.propertyTypes = propertyTypes
        self.notificationsEnabled = notificationsEnabled
        self.createdAt = createdAt
    }
}
