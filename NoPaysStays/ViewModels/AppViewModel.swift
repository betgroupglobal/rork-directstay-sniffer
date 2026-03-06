import SwiftUI
import MapKit

@Observable
final class AppViewModel {
    var currentCriteria: SearchCriteria = SearchCriteria()
    var searchResults: [PlatformSearch] = []
    var searchHistory: [SearchCriteria] = []
    var savedFinds: [SavedFind] = []
    var isSearching: Bool = false
    var hasSearched: Bool = false
    var checkedLinks: Set<String> = []

    func performSearch() {
        guard !currentCriteria.location.isEmpty else { return }
        isSearching = true
        searchResults = DeepSearchService.generateSearchLinks(for: currentCriteria)
        checkedLinks.removeAll()

        if !searchHistory.contains(where: {
            $0.location == currentCriteria.location &&
            $0.bedrooms == currentCriteria.bedrooms &&
            $0.guests == currentCriteria.guests
        }) {
            searchHistory.insert(currentCriteria, at: 0)
            if searchHistory.count > 50 {
                searchHistory = Array(searchHistory.prefix(50))
            }
            saveHistory()
        }

        hasSearched = true
        isSearching = false
    }

    func rerunSearch(_ criteria: SearchCriteria) {
        currentCriteria = criteria
        performSearch()
    }

    func markLinkChecked(_ id: String) {
        checkedLinks.insert(id)
    }

    func unmarkLinkChecked(_ id: String) {
        checkedLinks.remove(id)
    }

    func clearCheckedLinks() {
        checkedLinks.removeAll()
    }

    func clearHistory() {
        searchHistory.removeAll()
        saveHistory()
    }

    func deleteHistoryItem(_ criteria: SearchCriteria) {
        searchHistory.removeAll { $0.id == criteria.id }
        saveHistory()
    }

    func addSavedFind(_ find: SavedFind) {
        savedFinds.insert(find, at: 0)
        saveSavedFinds()
    }

    func deleteSavedFind(_ find: SavedFind) {
        savedFinds.removeAll { $0.id == find.id }
        saveSavedFinds()
    }

    func loadPersistedData() {
        if let data = UserDefaults.standard.data(forKey: "searchHistory"),
           let history = try? JSONDecoder().decode([SearchCriteria].self, from: data) {
            searchHistory = history
        }
        if let data = UserDefaults.standard.data(forKey: "savedFinds"),
           let finds = try? JSONDecoder().decode([SavedFind].self, from: data) {
            savedFinds = finds
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "searchHistory")
        }
    }

    private func saveSavedFinds() {
        if let data = try? JSONEncoder().encode(savedFinds) {
            UserDefaults.standard.set(data, forKey: "savedFinds")
        }
    }

    var resultsByCategory: [(PlatformCategory, [PlatformSearch])] {
        let grouped = Dictionary(grouping: searchResults) { $0.category }
        return grouped.sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map { ($0.key, $0.value) }
    }
}
