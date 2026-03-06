import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var selectedTab: AppTab = .explore

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Explore", systemImage: "map.fill", value: .explore) {
                ExploreView()
            }

            Tab("Search", systemImage: "magnifyingglass", value: .search) {
                SearchView()
            }

            Tab("Favorites", systemImage: "heart.fill", value: .favorites) {
                FavoritesView()
            }

            Tab("Alerts", systemImage: "bell.fill", value: .alerts) {
                AlertsView()
            }
            .badge(viewModel.unreadAlertCount)

            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
        .tint(AppTheme.burntOrange)
        .environment(viewModel)
        .onAppear {
            viewModel.loadFavorites()
        }
    }
}

enum AppTab: Hashable {
    case explore, search, favorites, alerts, settings
}
