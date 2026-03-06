import Foundation

nonisolated struct APISearchQuery: Sendable {
    let query: String
    let label: String
    let category: PlatformCategory
    let feeIndicator: String
}

enum DeepSearchService {
    static func generateSearchLinks(for criteria: SearchCriteria) -> [PlatformSearch] {
        var results: [PlatformSearch] = []
        let location = criteria.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else { return results }

        let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
        let encodedPlus = location.replacingOccurrences(of: " ", with: "+")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let checkInStr = criteria.checkIn.map { dateFormatter.string(from: $0) }
        let checkOutStr = criteria.checkOut.map { dateFormatter.string(from: $0) }

        results.append(contentsOf: alternativePlatforms(location: location, encoded: encoded, encodedPlus: encodedPlus, criteria: criteria, checkIn: checkInStr, checkOut: checkOutStr))
        results.append(contentsOf: classifieds(location: location, encoded: encoded, encodedPlus: encodedPlus, criteria: criteria))
        results.append(contentsOf: deepSearchQueries(location: location, encoded: encoded, criteria: criteria))
        results.append(contentsOf: socialMedia(location: location, encoded: encoded, criteria: criteria))
        results.append(contentsOf: tourismDirectories(location: location, encoded: encoded, criteria: criteria))
        results.append(contentsOf: directBookingQueries(location: location, encoded: encoded, criteria: criteria))

        return results
    }

    static func generatePlatformSearches(for criteria: SearchCriteria) -> [PlatformSearch] {
        var results: [PlatformSearch] = []
        let location = criteria.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else { return results }

        let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
        let encodedPlus = location.replacingOccurrences(of: " ", with: "+")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let checkInStr = criteria.checkIn.map { dateFormatter.string(from: $0) }
        let checkOutStr = criteria.checkOut.map { dateFormatter.string(from: $0) }

        results.append(contentsOf: alternativePlatforms(location: location, encoded: encoded, encodedPlus: encodedPlus, criteria: criteria, checkIn: checkInStr, checkOut: checkOutStr))
        results.append(contentsOf: classifieds(location: location, encoded: encoded, encodedPlus: encodedPlus, criteria: criteria))
        results.append(contentsOf: tourismDirectories(location: location, encoded: encoded, criteria: criteria))

        return results
    }

    static func generateAPIQueries(for criteria: SearchCriteria) -> [APISearchQuery] {
        let location = criteria.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else { return [] }

        var queries: [APISearchQuery] = []

        queries.append(APISearchQuery(
            query: "\"\(location)\" holiday rental \"book direct\" -airbnb -booking.com",
            label: "Direct Booking Search",
            category: .directBooking,
            feeIndicator: "0%"
        ))

        queries.append(APISearchQuery(
            query: "\"\(location)\" \"holiday house\" OR \"holiday home\" owner direct \(criteria.bedrooms) bedroom",
            label: "Owner Direct Search",
            category: .directBooking,
            feeIndicator: "0%"
        ))

        queries.append(APISearchQuery(
            query: "\"holiday letting\" OR \"holiday rental\" \"\(location)\" site:.com.au -airbnb -booking -stayz",
            label: "Local Agents Search",
            category: .searchEngine,
            feeIndicator: "Varies"
        ))

        queries.append(APISearchQuery(
            query: "\"\(location)\" accommodation \(criteria.bedrooms) bedroom \(criteria.guests) guest -airbnb.com -booking.com -expedia -hotels.com",
            label: "No-OTA Filter",
            category: .searchEngine,
            feeIndicator: "Varies"
        ))

        queries.append(APISearchQuery(
            query: "\"\(location)\" holiday rental phone email \"book direct\" site:.com.au",
            label: "Owner Contacts",
            category: .directBooking,
            feeIndicator: "0%"
        ))

        queries.append(APISearchQuery(
            query: "\"\(location)\" holiday house OR cottage OR cabin \"enquire\" OR \"contact us\" -airbnb -booking -stayz -vrbo",
            label: "Owner Websites",
            category: .directBooking,
            feeIndicator: "0%"
        ))

        if criteria.isPetFriendly {
            queries.append(APISearchQuery(
                query: "\"\(location)\" pet friendly holiday rental \"book direct\"",
                label: "Pet-Friendly Direct",
                category: .directBooking,
                feeIndicator: "0%"
            ))
        }

        queries.append(APISearchQuery(
            query: "site:stayz.com.au \"\(location)\" \(criteria.bedrooms) bedroom",
            label: "Stayz (API)",
            category: .alternativePlatform,
            feeIndicator: "5-8%"
        ))

        queries.append(APISearchQuery(
            query: "site:vrbo.com \"\(location)\" holiday rental",
            label: "Vrbo (API)",
            category: .alternativePlatform,
            feeIndicator: "6-12%"
        ))

        queries.append(APISearchQuery(
            query: "site:gumtree.com.au \"\(location)\" holiday accommodation",
            label: "Gumtree (API)",
            category: .classifieds,
            feeIndicator: "0%"
        ))

        queries.append(APISearchQuery(
            query: "\"\(location)\" holiday rental reddit OR whirlpool OR forum recommendation",
            label: "Community Picks",
            category: .socialMedia,
            feeIndicator: "N/A"
        ))

        queries.append(APISearchQuery(
            query: "\"\(location)\" council tourism accommodation directory",
            label: "Tourism Directories",
            category: .tourismDirectory,
            feeIndicator: "Varies"
        ))

        return queries
    }

    private static func alternativePlatforms(location: String, encoded: String, encodedPlus: String, criteria: SearchCriteria, checkIn: String?, checkOut: String?) -> [PlatformSearch] {
        var results: [PlatformSearch] = []

        var stayzURL = "https://www.stayz.com.au/search?destination=\(encoded)&adults=\(criteria.guests)&rooms=\(criteria.bedrooms)"
        if let ci = checkIn, let co = checkOut {
            stayzURL += "&startDate=\(ci)&endDate=\(co)"
        }
        if let url = URL(string: stayzURL) {
            results.append(PlatformSearch(
                platformName: "Stayz",
                category: .alternativePlatform,
                searchURL: url,
                description: "AU-focused whole-home rentals, lower fees than Airbnb",
                icon: "house.fill",
                feePercentage: "5-8%"
            ))
        }

        if let url = URL(string: "https://www.vrbo.com/search?destination=\(encoded)&adults=\(criteria.guests)&bedrooms=\(criteria.bedrooms)") {
            results.append(PlatformSearch(
                platformName: "Vrbo",
                category: .alternativePlatform,
                searchURL: url,
                description: "Whole-home bias, part of Expedia Group",
                icon: "house.lodge.fill",
                feePercentage: "6-12%"
            ))
        }

        if let url = URL(string: "https://www.ownerdirect.com/search?location=\(encoded)&guests=\(criteria.guests)&bedrooms=\(criteria.bedrooms)") {
            results.append(PlatformSearch(
                platformName: "OwnerDirect",
                category: .directBooking,
                searchURL: url,
                description: "Direct from owners, no service fees",
                icon: "person.fill.checkmark",
                feePercentage: "0%"
            ))
        }

        if let url = URL(string: "https://www.youcamp.com/search?location=\(encoded)") {
            results.append(PlatformSearch(
                platformName: "Youcamp",
                category: .alternativePlatform,
                searchURL: url,
                description: "Glamping, camping & outdoor stays",
                icon: "tent.fill",
                feePercentage: "~10%"
            ))
        }

        if let url = URL(string: "https://www.riparide.com/search?q=\(encoded)") {
            results.append(PlatformSearch(
                platformName: "Riparide",
                category: .alternativePlatform,
                searchURL: url,
                description: "Adventure & nature-based properties",
                icon: "figure.hiking",
                feePercentage: "~8%"
            ))
        }

        if let url = URL(string: "https://www.holidaypaws.com.au/search?location=\(encoded)") {
            results.append(PlatformSearch(
                platformName: "Holidaypaws",
                category: .alternativePlatform,
                searchURL: url,
                description: "Pet-friendly holiday homes",
                icon: "pawprint.fill",
                feePercentage: "Varies"
            ))
        }

        if let url = URL(string: "https://www.hometime.com.au/search?q=\(encoded)") {
            results.append(PlatformSearch(
                platformName: "Hometime",
                category: .alternativePlatform,
                searchURL: url,
                description: "Australian managed holiday rentals",
                icon: "clock.fill",
                feePercentage: "Varies"
            ))
        }

        if let url = URL(string: "https://www.holidayhouses.com.au/search?q=\(encoded)&bedrooms=\(criteria.bedrooms)&guests=\(criteria.guests)") {
            results.append(PlatformSearch(
                platformName: "Holiday Houses",
                category: .alternativePlatform,
                searchURL: url,
                description: "Australian holiday homes directory",
                icon: "house.and.flag.fill",
                feePercentage: "Low"
            ))
        }

        if let url = URL(string: "https://www.fairbnb.coop/search?location=\(encoded)") {
            results.append(PlatformSearch(
                platformName: "Fairbnb",
                category: .alternativePlatform,
                searchURL: url,
                description: "Community-focused ethical platform",
                icon: "hand.raised.fill",
                feePercentage: "~15%"
            ))
        }

        return results
    }

    private static func classifieds(location: String, encoded: String, encodedPlus: String, criteria: SearchCriteria) -> [PlatformSearch] {
        var results: [PlatformSearch] = []

        if let url = URL(string: "https://www.gumtree.com.au/s-holiday-accommodation/\(encoded)/k0c18661?sort=date") {
            results.append(PlatformSearch(
                platformName: "Gumtree",
                category: .classifieds,
                searchURL: url,
                description: "Holiday accommodation classifieds — often direct from owners",
                icon: "newspaper.fill",
                feePercentage: "0%"
            ))
        }

        if let url = URL(string: "https://www.facebook.com/marketplace/search/?query=holiday%20rental%20\(encoded)&category_id=propertyrentals") {
            results.append(PlatformSearch(
                platformName: "Facebook Marketplace",
                category: .classifieds,
                searchURL: url,
                description: "Private holiday rental listings, direct contact",
                icon: "bubble.left.fill",
                feePercentage: "0%"
            ))
        }

        if let url = URL(string: "https://www.domain.com.au/holiday/\(encoded.lowercased().replacingOccurrences(of: "%20", with: "-"))") {
            results.append(PlatformSearch(
                platformName: "Domain Holiday",
                category: .classifieds,
                searchURL: url,
                description: "Holiday letting via AU real estate portal",
                icon: "building.columns.fill",
                feePercentage: "Varies"
            ))
        }

        if let url = URL(string: "https://www.realestate.com.au/holiday/in-\(encoded.lowercased().replacingOccurrences(of: "%20", with: "-"))") {
            results.append(PlatformSearch(
                platformName: "REA Holiday",
                category: .classifieds,
                searchURL: url,
                description: "Holiday tabs on realestate.com.au",
                icon: "house.circle.fill",
                feePercentage: "Varies"
            ))
        }

        return results
    }

    private static func deepSearchQueries(location: String, encoded: String, criteria: SearchCriteria) -> [PlatformSearch] {
        var results: [PlatformSearch] = []

        let directQuery = "\"\(location)\" holiday rental \"book direct\" -airbnb -booking.com"
        if let url = URL(string: "https://www.google.com/search?q=\(directQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Google: Direct Booking",
                category: .searchEngine,
                searchURL: url,
                description: "Find owner websites with direct booking",
                icon: "magnifyingglass"
            ))
        }

        let ownerQuery = "\"\(location)\" \"holiday house\" OR \"holiday home\" owner direct \(criteria.bedrooms) bedroom"
        if let url = URL(string: "https://www.google.com/search?q=\(ownerQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Google: Owner Direct",
                category: .searchEngine,
                searchURL: url,
                description: "Search for owner-operated holiday homes",
                icon: "person.fill"
            ))
        }

        let localAgentQuery = "\"holiday letting\" OR \"holiday rental\" \"\(location)\" site:.com.au -airbnb -booking -stayz"
        if let url = URL(string: "https://www.google.com/search?q=\(localAgentQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Google: Local Agents",
                category: .searchEngine,
                searchURL: url,
                description: "Find local real estate agents with holiday lets",
                icon: "storefront.fill"
            ))
        }

        let petQuery = "\"\(location)\" pet friendly holiday rental \"book direct\""
        if criteria.isPetFriendly, let url = URL(string: "https://www.google.com/search?q=\(petQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Google: Pet-Friendly Direct",
                category: .searchEngine,
                searchURL: url,
                description: "Pet-friendly stays with direct booking options",
                icon: "pawprint.fill"
            ))
        }

        let noBrokerQuery = "\"\(location)\" accommodation \(criteria.bedrooms) bedroom \(criteria.guests) guest -airbnb.com -booking.com -expedia -hotels.com"
        if let url = URL(string: "https://www.google.com/search?q=\(noBrokerQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Google: No OTA Filter",
                category: .searchEngine,
                searchURL: url,
                description: "Exclude all major OTAs from results",
                icon: "xmark.shield.fill"
            ))
        }

        let bingQuery = "\"\(location)\" holiday rental book direct owner -airbnb -booking"
        if let url = URL(string: "https://www.bing.com/search?q=\(bingQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Bing: Direct Booking",
                category: .searchEngine,
                searchURL: url,
                description: "Bing often surfaces different results than Google",
                icon: "globe"
            ))
        }

        let ddgQuery = "\"\(location)\" holiday accommodation direct owner \(criteria.bedrooms) bed"
        if let url = URL(string: "https://duckduckgo.com/?q=\(ddgQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "DuckDuckGo: Direct",
                category: .searchEngine,
                searchURL: url,
                description: "Privacy-friendly search, less SEO manipulation",
                icon: "eye.slash.fill"
            ))
        }

        return results
    }

    private static func socialMedia(location: String, encoded: String, criteria: SearchCriteria) -> [PlatformSearch] {
        var results: [PlatformSearch] = []

        let fbGroupQuery = "\"\(location)\" holiday rental group"
        if let url = URL(string: "https://www.facebook.com/search/groups/?q=\(fbGroupQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Facebook Groups",
                category: .socialMedia,
                searchURL: url,
                description: "Local holiday rental community groups",
                icon: "person.3.fill"
            ))
        }

        let redditQuery = "\(location) holiday rental OR accommodation OR airbnb alternative"
        if let url = URL(string: "https://www.reddit.com/search/?q=\(redditQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&sort=new") {
            results.append(PlatformSearch(
                platformName: "Reddit",
                category: .socialMedia,
                searchURL: url,
                description: "Community discussions & recommendations",
                icon: "text.bubble.fill"
            ))
        }

        let whirlpoolQuery = "\(location) holiday rental"
        if let url = URL(string: "https://forums.whirlpool.net.au/search?q=\(whirlpoolQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Whirlpool Forums",
                category: .socialMedia,
                searchURL: url,
                description: "Australia's largest tech/travel forum",
                icon: "bubble.left.and.text.bubble.right.fill"
            ))
        }

        return results
    }

    private static func tourismDirectories(location: String, encoded: String, criteria: SearchCriteria) -> [PlatformSearch] {
        var results: [PlatformSearch] = []

        if let url = URL(string: "https://www.visitnsw.com/accommodation?q=\(encoded)") {
            results.append(PlatformSearch(
                platformName: "Visit NSW",
                category: .tourismDirectory,
                searchURL: url,
                description: "Official NSW tourism accommodation directory",
                icon: "mappin.and.ellipse"
            ))
        }

        if let url = URL(string: "https://www.visitvictoria.com/accommodation?q=\(encoded)") {
            results.append(PlatformSearch(
                platformName: "Visit Victoria",
                category: .tourismDirectory,
                searchURL: url,
                description: "Official VIC tourism accommodation directory",
                icon: "mappin.and.ellipse"
            ))
        }

        if let url = URL(string: "https://www.queensland.com/au/en/accommodation?q=\(encoded)") {
            results.append(PlatformSearch(
                platformName: "Queensland.com",
                category: .tourismDirectory,
                searchURL: url,
                description: "Official QLD tourism accommodation directory",
                icon: "mappin.and.ellipse"
            ))
        }

        if let url = URL(string: "https://www.westernaustralia.com/au/accommodation?q=\(encoded)") {
            results.append(PlatformSearch(
                platformName: "WA Tourism",
                category: .tourismDirectory,
                searchURL: url,
                description: "Official WA tourism accommodation directory",
                icon: "mappin.and.ellipse"
            ))
        }

        let councilQuery = "\"\(location)\" council tourism accommodation directory"
        if let url = URL(string: "https://www.google.com/search?q=\(councilQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Local Council Directory",
                category: .tourismDirectory,
                searchURL: url,
                description: "Search for local council tourism portals",
                icon: "building.2.fill"
            ))
        }

        return results
    }

    private static func directBookingQueries(location: String, encoded: String, criteria: SearchCriteria) -> [PlatformSearch] {
        var results: [PlatformSearch] = []

        let phoneQuery = "\"\(location)\" holiday rental phone email \"book direct\" site:.com.au"
        if let url = URL(string: "https://www.google.com/search?q=\(phoneQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Google: Owner Contacts",
                category: .directBooking,
                searchURL: url,
                description: "Find owner phone numbers and emails",
                icon: "phone.fill"
            ))
        }

        let micrositeQuery = "\"\(location)\" holiday house OR cottage OR cabin \"enquire\" OR \"contact us\" -airbnb -booking -stayz -vrbo"
        if let url = URL(string: "https://www.google.com/search?q=\(micrositeQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            results.append(PlatformSearch(
                platformName: "Google: Owner Websites",
                category: .directBooking,
                searchURL: url,
                description: "Find private owner microsites with booking forms",
                icon: "globe"
            ))
        }

        return results
    }

    private static func extractState(from location: String) -> String? {
        let upper = location.uppercased()
        let states = ["NSW", "VIC", "QLD", "WA", "SA", "TAS", "NT", "ACT"]
        return states.first { upper.contains($0) }
    }
}
