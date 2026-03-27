import SwiftUI

struct FavoritesView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedProperty: Property?
    @State private var appeared: Bool = false
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.favoriteProperties.isEmpty {
                    ContentUnavailableView(
                        "No Favorites Yet",
                        systemImage: "heart.slash",
                        description: Text("Tap the heart on any property to save it here")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(Array(viewModel.favoriteProperties.enumerated()), id: \.element.id) { index, property in
                                Button {
                                    selectedProperty = property
                                } label: {
                                    FavoriteCardView(
                                        property: property,
                                        onRemove: { viewModel.toggleFavorite(property) }
                                    )
                                }
                                .buttonStyle(.plain)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(.spring(response: 0.4).delay(Double(index) * 0.06), value: appeared)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .onAppear { appeared = true }
                }
            }
            .navigationTitle("Favorites")
            .sheet(item: $selectedProperty) { property in
                PropertyDetailView(property: property)
            }
        }
    }
}

struct FavoriteCardView: View {
    let property: Property
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color(.secondarySystemBackground)
                .frame(height: 130)
                .overlay {
                    AsyncImage(url: URL(string: property.imageURLs.first ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 12))
                .overlay(alignment: .topTrailing) {
                    Button { onRemove() } label: {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.coral)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(6)
                }
                .overlay(alignment: .bottomLeading) {
                    if let savings = property.savingsPercentage {
                        Text("-\(savings)%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.savingsGreen, in: Capsule())
                            .padding(6)
                    }
                }

            Text(property.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Text("\(property.suburb), \(property.state)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 2) {
                if let alt = property.bestAlternativePrice {
                    Text("$\(Int(alt))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.savingsGreen)
                } else {
                    Text("$\(Int(property.otaPrice))")
                        .font(.subheadline.weight(.bold))
                }
                Text("/night")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
