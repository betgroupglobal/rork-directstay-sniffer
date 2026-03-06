import SwiftUI

struct SettingsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var notificationsEnabled: Bool = true
    @State private var directOnlyAlerts: Bool = false

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

                            Image(systemName: "house.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("NoPays Stays")
                                .font(.headline)
                            Text("Skip the fees. Book direct.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section("Notifications") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Push Notifications", systemImage: "bell.fill")
                    }
                    .tint(AppTheme.burntOrange)

                    Toggle(isOn: $directOnlyAlerts) {
                        Label("Direct Booking Alerts Only", systemImage: "checkmark.seal.fill")
                    }
                    .tint(AppTheme.savingsGreen)
                }

                Section("Saved Searches") {
                    if viewModel.savedSearches.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title3)
                                    .foregroundStyle(.tertiary)
                                Text("No saved searches")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                            Spacer()
                        }
                    } else {
                        ForEach(viewModel.savedSearches) { search in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(search.locationName)
                                        .font(.subheadline.weight(.medium))
                                    HStack(spacing: 8) {
                                        Label("\(search.guests)", systemImage: "person.2.fill")
                                        Label("\(Int(search.radiusKm))km", systemImage: "circle.dashed")
                                        if search.isPetFriendly {
                                            Image(systemName: "pawprint.fill")
                                                .foregroundStyle(AppTheme.burntOrange)
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: search.notificationsEnabled ? "bell.fill" : "bell.slash")
                                    .font(.caption)
                                    .foregroundStyle(search.notificationsEnabled ? AppTheme.burntOrange : Color.gray.opacity(0.4))
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel.deleteSavedSearch(viewModel.savedSearches[index])
                            }
                        }
                    }
                }

                Section("Data") {
                    HStack {
                        Label("Properties Cached", systemImage: "square.stack.3d.up.fill")
                        Spacer()
                        Text("\(viewModel.properties.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Favorites", systemImage: "heart.fill")
                        Spacer()
                        Text("\(viewModel.favoriteIDs.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://nopaysstays.com.au")!) {
                        Label("Website", systemImage: "globe")
                    }

                    Link(destination: URL(string: "mailto:support@nopaysstays.com.au")!) {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                }

                Section {
                    VStack(spacing: 4) {
                        Text("NoPays Stays finds you the cheapest way to book holiday rentals by discovering direct-booking options hidden behind mainstream platforms.")
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
}
