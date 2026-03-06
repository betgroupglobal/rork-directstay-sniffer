import SwiftUI

struct PropertyCardView: View {
    let property: Property
    let isFavorite: Bool
    let onFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(.secondarySystemBackground)
                .frame(height: 180)
                .overlay {
                    AsyncImage(url: URL(string: property.imageURLs.first ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0.3), .init(color: .black.opacity(0.7), location: 1.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(.rect(cornerRadius: 14, style: .continuous))
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(property.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(property.suburb), \(property.state)")
                            .font(.caption)
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    Button { onFavorite() } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isFavorite ? AppTheme.coral : .white)
                            .padding(7)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    .padding(8)
                }
                .overlay(alignment: .topLeading) {
                    if let savings = property.savingsPercentage {
                        Text("Save \(savings)%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.savingsGreen, in: Capsule())
                            .padding(8)
                    }
                }

            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: property.propertyType.icon)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.burntOrange)
                        Text(property.propertyType.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Label("\(property.bedrooms)", systemImage: "bed.double.fill")
                        Label("\(property.bathrooms)", systemImage: "shower.fill")
                        Label("\(property.maxGuests)", systemImage: "person.2.fill")
                        if property.isPetFriendly {
                            Image(systemName: "pawprint.fill")
                                .foregroundStyle(AppTheme.burntOrange)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let altPrice = property.bestAlternativePrice {
                        Text("$\(Int(property.otaPrice))")
                            .font(.caption)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Text("$\(Int(altPrice))")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.savingsGreen)
                    } else {
                        Text("$\(Int(property.otaPrice))")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    Text("/night")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }
}
