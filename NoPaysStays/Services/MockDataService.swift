import Foundation

enum MockDataService {
    static let properties: [Property] = [
        Property(
            id: "prop-001",
            title: "Oceanfront Beach House",
            subtitle: "Stunning views of Byron Bay Main Beach",
            address: "42 Lighthouse Road",
            suburb: "Byron Bay",
            state: "NSW",
            postcode: "2481",
            latitude: -28.6436,
            longitude: 153.6120,
            propertyType: .beachHouse,
            bedrooms: 4,
            bathrooms: 2,
            maxGuests: 8,
            isPetFriendly: true,
            amenities: ["Pool", "WiFi", "BBQ", "Parking", "Ocean View", "Air Con"],
            imageURLs: [
                "https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800",
                "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800",
                "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800"
            ],
            bookingLinks: [
                BookingLink(id: "bl-001a", platform: "Airbnb", url: "https://airbnb.com/rooms/123", pricePerNight: 420, totalPrice: 2940, isDirectBooking: false, feesIncluded: true),
                BookingLink(id: "bl-001b", platform: "Owner Direct", url: "https://byronbeachhouse.com.au/book", pricePerNight: 310, totalPrice: 2170, isDirectBooking: true, feesIncluded: true),
                BookingLink(id: "bl-001c", platform: "Stayz", url: "https://stayz.com.au/listing/456", pricePerNight: 365, totalPrice: 2555, isDirectBooking: false, feesIncluded: true)
            ],
            ownerContact: OwnerContact(name: "Sarah Mitchell", phone: "0412 345 678", email: "sarah@byronbeachhouse.com.au", website: "byronbeachhouse.com.au", confidence: 0.92),
            bookingStrength: .direct,
            otaPrice: 420,
            bestAlternativePrice: 310,
            discoveredAt: Date().addingTimeInterval(-86400 * 2)
        ),
        Property(
            id: "prop-002",
            title: "Hinterland Retreat Cabin",
            subtitle: "Secluded rainforest hideaway near Bangalow",
            address: "15 Possum Creek Road",
            suburb: "Bangalow",
            state: "NSW",
            postcode: "2479",
            latitude: -28.6867,
            longitude: 153.5241,
            propertyType: .cabin,
            bedrooms: 2,
            bathrooms: 1,
            maxGuests: 4,
            isPetFriendly: false,
            amenities: ["WiFi", "Fireplace", "Bushwalking", "Spa Bath", "Deck"],
            imageURLs: [
                "https://images.unsplash.com/photo-1449158743715-0a90ebb6d2d8?w=800",
                "https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800"
            ],
            bookingLinks: [
                BookingLink(id: "bl-002a", platform: "Booking.com", url: "https://booking.com/hotel/789", pricePerNight: 280, totalPrice: 1960, isDirectBooking: false, feesIncluded: true),
                BookingLink(id: "bl-002b", platform: "Stayz", url: "https://stayz.com.au/listing/321", pricePerNight: 245, totalPrice: 1715, isDirectBooking: false, feesIncluded: true)
            ],
            ownerContact: nil,
            bookingStrength: .alternative,
            otaPrice: 280,
            bestAlternativePrice: 245,
            discoveredAt: Date().addingTimeInterval(-86400 * 1)
        ),
        Property(
            id: "prop-003",
            title: "Noosa Heads Penthouse",
            subtitle: "Luxury apartment overlooking Hastings Street",
            address: "88 Hastings Street",
            suburb: "Noosa Heads",
            state: "QLD",
            postcode: "4567",
            latitude: -26.3889,
            longitude: 153.0903,
            propertyType: .apartment,
            bedrooms: 3,
            bathrooms: 2,
            maxGuests: 6,
            isPetFriendly: false,
            amenities: ["Pool", "WiFi", "Gym", "Balcony", "Air Con", "Lift"],
            imageURLs: [
                "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800",
                "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800"
            ],
            bookingLinks: [
                BookingLink(id: "bl-003a", platform: "Airbnb", url: "https://airbnb.com/rooms/456", pricePerNight: 550, totalPrice: 3850, isDirectBooking: false, feesIncluded: true),
                BookingLink(id: "bl-003b", platform: "Owner Direct", url: "https://noosapenthouse.com.au", pricePerNight: 420, totalPrice: 2940, isDirectBooking: true, feesIncluded: true),
                BookingLink(id: "bl-003c", platform: "Booking.com", url: "https://booking.com/hotel/321", pricePerNight: 510, totalPrice: 3570, isDirectBooking: false, feesIncluded: true)
            ],
            ownerContact: OwnerContact(name: "David Chen", phone: nil, email: "bookings@noosapenthouse.com.au", website: "noosapenthouse.com.au", confidence: 0.88),
            bookingStrength: .direct,
            otaPrice: 550,
            bestAlternativePrice: 420,
            discoveredAt: Date().addingTimeInterval(-86400 * 3)
        ),
        Property(
            id: "prop-004",
            title: "Torquay Surf Shack",
            subtitle: "Steps from Bells Beach, perfect for surfers",
            address: "7 Surf Coast Highway",
            suburb: "Torquay",
            state: "VIC",
            postcode: "3228",
            latitude: -38.3318,
            longitude: 144.3260,
            propertyType: .house,
            bedrooms: 3,
            bathrooms: 1,
            maxGuests: 6,
            isPetFriendly: true,
            amenities: ["WiFi", "BBQ", "Surfboard Storage", "Outdoor Shower", "Parking"],
            imageURLs: [
                "https://images.unsplash.com/photo-1505873242700-f289a29e1e0f?w=800",
                "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800"
            ],
            bookingLinks: [
                BookingLink(id: "bl-004a", platform: "Airbnb", url: "https://airbnb.com/rooms/789", pricePerNight: 320, totalPrice: 2240, isDirectBooking: false, feesIncluded: true)
            ],
            ownerContact: nil,
            bookingStrength: .mainstreamOnly,
            otaPrice: 320,
            bestAlternativePrice: nil,
            discoveredAt: Date().addingTimeInterval(-86400 * 5)
        ),
        Property(
            id: "prop-005",
            title: "Margaret River Vineyard Stay",
            subtitle: "Wake up among the vines in WA wine country",
            address: "200 Caves Road",
            suburb: "Margaret River",
            state: "WA",
            postcode: "6285",
            latitude: -33.9536,
            longitude: 115.0753,
            propertyType: .farmStay,
            bedrooms: 2,
            bathrooms: 2,
            maxGuests: 4,
            isPetFriendly: false,
            amenities: ["Wine Tasting", "WiFi", "Breakfast", "Garden", "Fire Pit"],
            imageURLs: [
                "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800",
                "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800"
            ],
            bookingLinks: [
                BookingLink(id: "bl-005a", platform: "Booking.com", url: "https://booking.com/hotel/555", pricePerNight: 380, totalPrice: 2660, isDirectBooking: false, feesIncluded: true),
                BookingLink(id: "bl-005b", platform: "Gumtree", url: "https://gumtree.com.au/s-ad/123", pricePerNight: 280, totalPrice: 1960, isDirectBooking: true, feesIncluded: true)
            ],
            ownerContact: OwnerContact(name: "Tom & Lisa Hardy", phone: "0438 765 432", email: nil, website: nil, confidence: 0.75),
            bookingStrength: .direct,
            otaPrice: 380,
            bestAlternativePrice: 280,
            discoveredAt: Date().addingTimeInterval(-86400 * 1)
        ),
        Property(
            id: "prop-006",
            title: "Port Douglas Tropical Villa",
            subtitle: "Private pool villa near Four Mile Beach",
            address: "33 Port Street",
            suburb: "Port Douglas",
            state: "QLD",
            postcode: "4877",
            latitude: -16.4837,
            longitude: 145.4627,
            propertyType: .house,
            bedrooms: 4,
            bathrooms: 3,
            maxGuests: 10,
            isPetFriendly: true,
            amenities: ["Private Pool", "WiFi", "Air Con", "BBQ", "Tropical Garden", "Parking"],
            imageURLs: [
                "https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800",
                "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800"
            ],
            bookingLinks: [
                BookingLink(id: "bl-006a", platform: "Airbnb", url: "https://airbnb.com/rooms/999", pricePerNight: 480, totalPrice: 3360, isDirectBooking: false, feesIncluded: true),
                BookingLink(id: "bl-006b", platform: "Stayz", url: "https://stayz.com.au/listing/888", pricePerNight: 410, totalPrice: 2870, isDirectBooking: false, feesIncluded: true),
                BookingLink(id: "bl-006c", platform: "Hometime", url: "https://hometime.com.au/listing/777", pricePerNight: 395, totalPrice: 2765, isDirectBooking: false, feesIncluded: true)
            ],
            ownerContact: nil,
            bookingStrength: .alternative,
            otaPrice: 480,
            bestAlternativePrice: 395,
            discoveredAt: Date().addingTimeInterval(-3600 * 6)
        ),
        Property(
            id: "prop-007",
            title: "Lorne Glamping Dome",
            subtitle: "Unique eco-glamping on the Great Ocean Road",
            address: "12 Otway Range Drive",
            suburb: "Lorne",
            state: "VIC",
            postcode: "3232",
            latitude: -38.5418,
            longitude: 143.9789,
            propertyType: .glamping,
            bedrooms: 1,
            bathrooms: 1,
            maxGuests: 2,
            isPetFriendly: false,
            amenities: ["Stargazing Roof", "Outdoor Bath", "Breakfast Hamper", "Bushwalk Access"],
            imageURLs: [
                "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800",
                "https://images.unsplash.com/photo-1534880606858-29b0e8a24e8a?w=800"
            ],
            bookingLinks: [
                BookingLink(id: "bl-007a", platform: "Youcamp", url: "https://youcamp.com/listing/456", pricePerNight: 220, totalPrice: 1540, isDirectBooking: false, feesIncluded: true),
                BookingLink(id: "bl-007b", platform: "Owner Direct", url: "https://lorneglamp.com.au", pricePerNight: 195, totalPrice: 1365, isDirectBooking: true, feesIncluded: true)
            ],
            ownerContact: OwnerContact(name: "Emma Wallace", phone: "0421 987 654", email: "hello@lorneglamp.com.au", website: "lorneglamp.com.au", confidence: 0.95),
            bookingStrength: .direct,
            otaPrice: 220,
            bestAlternativePrice: 195,
            discoveredAt: Date().addingTimeInterval(-3600 * 12)
        )
    ]

    static let alerts: [PropertyAlert] = [
        PropertyAlert(
            property: properties[0],
            savedSearchId: "search-001",
            savedSearchName: "Byron Bay",
            savingsPercentage: 26,
            discoveredAt: Date().addingTimeInterval(-3600 * 2)
        ),
        PropertyAlert(
            property: properties[4],
            savedSearchId: "search-002",
            savedSearchName: "Margaret River",
            savingsPercentage: 26,
            discoveredAt: Date().addingTimeInterval(-3600 * 8)
        ),
        PropertyAlert(
            property: properties[6],
            savedSearchId: "search-003",
            savedSearchName: "Great Ocean Road",
            savingsPercentage: 11,
            discoveredAt: Date().addingTimeInterval(-86400)
        ),
        PropertyAlert(
            property: properties[2],
            savedSearchId: "search-004",
            savedSearchName: "Noosa QLD",
            savingsPercentage: 24,
            discoveredAt: Date().addingTimeInterval(-86400 * 2)
        )
    ]

    static let savedSearches: [SavedSearch] = [
        SavedSearch(locationName: "Byron Bay, NSW", latitude: -28.6436, longitude: 153.6120, radiusKm: 30, guests: 4, isPetFriendly: true),
        SavedSearch(locationName: "Noosa, QLD", latitude: -26.3889, longitude: 153.0903, radiusKm: 20, guests: 2),
        SavedSearch(locationName: "Great Ocean Road, VIC", latitude: -38.4418, longitude: 144.1789, radiusKm: 50, guests: 2)
    ]
}
