import SwiftUI

struct SettingsView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            LinearGradient(
                                colors: [AppTheme.coral, AppTheme.burntOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: 54, height: 54)
                            .clipShape(.rect(cornerRadius: 14))

                            Image(systemName: "binoculars.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("NoPays Stays")
                                .font(.headline)
                            Text("Automated direct booking hunter")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section("Search Stats") {
                    HStack {
                        Label("Hunts Completed", systemImage: "binoculars.fill")
                        Spacer()
                        Text("\(viewModel.searchHistory.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Saved Finds", systemImage: "bookmark.fill")
                        Spacer()
                        Text("\(viewModel.savedFinds.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 12) {
                        StepRow(number: 1, title: "Set Your Criteria", description: "Location, dates, bedrooms, bathrooms, guests", icon: "pencil.circle.fill")
                        StepRow(number: 2, title: "Launch the Hunt", description: "App generates 30+ targeted search queries", icon: "bolt.circle.fill")
                        StepRow(number: 3, title: "Auto-Hunt Mode", description: "Opens each source in-app — close to advance to next", icon: "binoculars.circle.fill")
                        StepRow(number: 4, title: "Save Direct Finds", description: "Bookmark the best deals you discover", icon: "bookmark.circle.fill")
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Platforms Searched") {
                    PlatformGroupRow(title: "Direct Booking", count: "2+", description: "Owner contacts, microsites, phone/email extraction", color: AppTheme.savingsGreen)
                    PlatformGroupRow(title: "Alternative Platforms", count: "9", description: "Stayz, Vrbo, OwnerDirect, Youcamp, Riparide, Holidaypaws, Hometime, Holiday Houses, Fairbnb", color: AppTheme.burntOrange)
                    PlatformGroupRow(title: "Classifieds", count: "4", description: "Gumtree, Facebook Marketplace, Domain Holiday, REA Holiday", color: AppTheme.amber)
                    PlatformGroupRow(title: "Search Engines", count: "7", description: "Google deep queries, Bing, DuckDuckGo — excluding OTAs", color: AppTheme.coral)
                    PlatformGroupRow(title: "Social & Forums", count: "3", description: "Facebook Groups, Reddit, Whirlpool", color: AppTheme.dustyPurple)
                    PlatformGroupRow(title: "Tourism Directories", count: "5", description: "Visit NSW/VIC/QLD, WA Tourism, Local Councils", color: .blue)
                }

                Section("Search API Status") {
                    apiStatusRow("Google Custom Search", configured: !WebSearchAPIService.googleAPIKey.isEmpty && !WebSearchAPIService.googleCX.isEmpty)
                    apiStatusRow("Bing Web Search", configured: !WebSearchAPIService.bingAPIKey.isEmpty)
                    apiStatusRow("SerpAPI", configured: !WebSearchAPIService.serpAPIKey.isEmpty)
                    apiStatusRow("Brave Search", configured: !WebSearchAPIService.braveAPIKey.isEmpty)

                    if SearchAPIProvider.configuredProviders.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.warningAmber)
                            Text("No search APIs configured. Spider will use HTML scraping as fallback (less reliable).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.savingsGreen)
                            Text("API-powered search active — structured results, no scraping timeouts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("3.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    VStack(spacing: 4) {
                        Text("NoPays Stays automates the hunt for direct holiday bookings. Instead of manually searching 30+ platforms, the app does it for you — opening each source in-app so you can check, save, and move on.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .listRowBackground(Color.clear)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func apiStatusRow(_ name: String, configured: Bool) -> some View {
        HStack {
            Label(name, systemImage: configured ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(configured ? AppTheme.savingsGreen : .secondary)
            Spacer()
            Text(configured ? "Active" : "Not Set")
                .font(.caption.weight(.medium))
                .foregroundStyle(configured ? AppTheme.savingsGreen : Color.secondary)
        }
    }
}

struct StepRow: View {
    let number: Int
    let title: String
    let description: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.burntOrange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(number). \(title)")
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PlatformGroupRow: View {
    let title: String
    let count: String
    let description: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(count)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color, in: Capsule())
            }
            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
