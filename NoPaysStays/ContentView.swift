import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var selectedTab: AppTab = .search

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Search", systemImage: "magnifyingglass", value: .search) {
                SearchView()
            }

            Tab("Saved", systemImage: "bookmark.fill", value: .saved) {
                SavedFindsView()
            }

            Tab("History", systemImage: "clock.arrow.circlepath", value: .history) {
                HistoryView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
        .tint(AppTheme.burntOrange)
        .environment(viewModel)
        .onAppear {
            viewModel.loadPersistedData()
        }
    }
}

enum AppTab: Hashable {
    case search, saved, history, settings
}
