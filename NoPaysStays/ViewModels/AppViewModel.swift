import SwiftUI
import MapKit

@Observable
final class AppViewModel {
    var properties: [Property] = MockDataService.properties
    var searchResults: [Property] = []
    var favoriteIDs: Set<String> = []
    var savedSearches: [SavedSearch] = MockDataService.savedSearches
    var alerts: [PropertyAlert] = MockDataService.alerts
    var selectedProperty: Property?
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var hasSearched: Bool = false

    var filterPetFriendly: Bool = false
    var filterDirectOnly: Bool = false
    var filterMinGuests: Int = 1
    var filterPropertyTypes: Set<PropertyType> = []

    var filteredProperties: [Property] {
        properties.filter { property in
            if filterPetFriendly && !property.isPetFriendly { return false }
            if filterDirectOnly && property.bookingStrength == .mainstreamOnly { return false }
            if property.maxGuests < filterMinGuests { return false }
            if !filterPropertyTypes.isEmpty && !filterPropertyTypes.contains(property.propertyType) { return false }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesLocation = property.suburb.lowercased().contains(query)
                    || property.state.lowercased().contains(query)
                    || property.postcode.contains(query)
                    || property.title.lowercased().contains(query)
                if !matchesLocation { return false }
            }
            return true
        }
    }

    var unreadAlertCount: Int {
        alerts.filter { !$0.isRead }.count
    }

    func isFavorite(_ property: Property) -> Bool {
        favoriteIDs.contains(property.id)
    }

    func toggleFavorite(_ property: Property) {
        if favoriteIDs.contains(property.id) {
            favoriteIDs.remove(property.id)
        } else {
            favoriteIDs.insert(property.id)
        }
        saveFavorites()
    }

    var favoriteProperties: [Property] {
        properties.filter { favoriteIDs.contains($0.id) }
    }

    func markAlertRead(_ alert: PropertyAlert) {
        guard let index = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[index].isRead = true
    }

    func markAllAlertsRead() {
        for index in alerts.indices {
            alerts[index].isRead = true
        }
    }

    func deleteSavedSearch(_ search: SavedSearch) {
        savedSearches.removeAll { $0.id == search.id }
    }

    func addSavedSearch(_ search: SavedSearch) {
        savedSearches.append(search)
    }

    func clearFilters() {
        filterPetFriendly = false
        filterDirectOnly = false
        filterMinGuests = 1
        filterPropertyTypes = []
    }

    func searchAPI(
        location: String,
        checkIn: Date? = nil,
        checkOut: Date? = nil,
        guests: Int? = nil,
        petFriendly: Bool? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        hasSearched = true

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = CrawlRequest(
            location: location,
            check_in: checkIn.map { formatter.string(from: $0) },
            check_out: checkOut.map { formatter.string(from: $0) },
            guests: guests,
            pet_friendly: petFriendly == true ? true : nil,
            max_results: 30
        )

        do {
            let results = try await APIService.shared.crawlToProperties(request)
            searchResults = results
            properties = MockDataService.properties + results
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
        }

        isLoading = false
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(Array(favoriteIDs)) {
            UserDefaults.standard.set(data, forKey: "favoriteIDs")
        }
    }

    func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: "favoriteIDs"),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return }
        favoriteIDs = Set(ids)
    }
}
