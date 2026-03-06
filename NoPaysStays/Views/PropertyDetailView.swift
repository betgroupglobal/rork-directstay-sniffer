import SwiftUI

struct PropertyDetailView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let property: Property
    @State private var selectedImageIndex: Int = 0
    @State private var showDirectFinder: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    imageCarousel
                    contentSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        ShareLink(item: property.bookingLinks.first?.url ?? property.title) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button {
                            viewModel.toggleFavorite(property)
                        } label: {
                            Image(systemName: viewModel.isFavorite(property) ? "heart.fill" : "heart")
                                .foregroundStyle(viewModel.isFavorite(property) ? AppTheme.coral : .primary)
                        }
                        .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.isFavorite(property))
                    }
                }
            }
        }
    }

    private var imageCarousel: some View {
        TabView(selection: $selectedImageIndex) {
            ForEach(Array(property.imageURLs.enumerated()), id: \.offset) { index, urlString in
                Color(.secondarySystemBackground)
                    .overlay {
                        AsyncImage(url: URL(string: urlString)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipped()
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 280)
        .overlay(alignment: .topLeading) {
            if let savings = property.savingsPercentage {
                Text("Save \(savings)%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.savingsGreen, in: Capsule())
                    .padding(16)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            strengthBadge
                .padding(16)
        }
    }

    private var strengthBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(AppTheme.pinColor(for: property.bookingStrength))
                .frame(width: 8, height: 8)
            Text(property.bookingStrength.label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(property.title)
                    .font(.title2.weight(.bold))

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(AppTheme.coral)
                    Text("\(property.suburb), \(property.state) \(property.postcode)")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                HStack(spacing: 16) {
                    Label("\(property.bedrooms) Bed", systemImage: "bed.double.fill")
                    Label("\(property.bathrooms) Bath", systemImage: "shower.fill")
                    Label("\(property.maxGuests) Guests", systemImage: "person.2.fill")
                    if property.isPetFriendly {
                        Label("Pets OK", systemImage: "pawprint.fill")
                            .foregroundStyle(AppTheme.burntOrange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }

            Divider()

            priceComparisonSection

            Divider()

            amenitiesSection

            Divider()
            directBookingLookupSection

            if let contact = property.ownerContact {
                Divider()
                ownerContactSection(contact)
            }

            if let cheapest = property.cheapestLink {
                Button {
                    if let url = URL(string: cheapest.url) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cheapest.isDirectBooking ? "Book Direct" : "Book on \(cheapest.platform)")
                                .font(.headline)
                            Text("$\(Int(cheapest.pricePerNight))/night")
                                .font(.subheadline.weight(.medium))
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.title2)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.coral, AppTheme.burntOrange],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: .rect(cornerRadius: 14)
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
    }

    private var priceComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price Comparison")
                .font(.headline)

            ForEach(property.bookingLinks.sorted(by: { $0.pricePerNight < $1.pricePerNight })) { link in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(link.platform)
                                .font(.subheadline.weight(.medium))
                            if link.isDirectBooking {
                                Text("DIRECT")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.savingsGreen, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                        if link.feesIncluded {
                            Text("Fees included")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("$\(Int(link.pricePerNight))")
                            .font(.headline)
                            .foregroundStyle(link == property.cheapestLink ? AppTheme.savingsGreen : .primary)
                        Text("/night")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(
                    link == property.cheapestLink
                        ? AppTheme.savingsGreen.opacity(0.08)
                        : Color(.tertiarySystemBackground)
                )
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(link == property.cheapestLink ? AppTheme.savingsGreen.opacity(0.3) : .clear, lineWidth: 1)
                )
            }
        }
    }

    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Amenities")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(property.amenities, id: \.self) { amenity in
                    HStack(spacing: 4) {
                        Image(systemName: amenityIcon(for: amenity))
                            .font(.caption)
                            .foregroundStyle(AppTheme.burntOrange)
                        Text(amenity)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func ownerContactSection(_ contact: OwnerContact) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Owner Contact")
                    .font(.headline)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5) { i in
                        Image(systemName: Double(i) < contact.confidence * 5 ? "circle.fill" : "circle")
                            .font(.system(size: 6))
                            .foregroundStyle(AppTheme.savingsGreen)
                    }
                    Text("\(Int(contact.confidence * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let name = contact.name {
                Label(name, systemImage: "person.fill")
                    .font(.subheadline)
            }
            if let phone = contact.phone {
                Button {
                    if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(phone, systemImage: "phone.fill")
                        .font(.subheadline)
                }
            }
            if let email = contact.email {
                Button {
                    if let url = URL(string: "mailto:\(email)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(email, systemImage: "envelope.fill")
                        .font(.subheadline)
                }
            }
            if let website = contact.website {
                Button {
                    if let url = URL(string: "https://\(website)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(website, systemImage: "globe")
                        .font(.subheadline)
                }
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var directBookingLookupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Find Direct Booking")
                    .font(.headline)
                Spacer()
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.amber)
            }

            Text("Search the web for this property's owner website, direct booking page, or cheaper alternatives.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showDirectFinder = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search for Direct Site")
                            .font(.subheadline.weight(.semibold))
                        Text("Property name, host, address lookup")
                            .font(.caption2)
                            .opacity(0.8)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle")
                        .font(.body)
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [AppTheme.savingsGreen, AppTheme.savingsGreen.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .rect(cornerRadius: 12)
                )
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: showDirectFinder)
            .sheet(isPresented: $showDirectFinder) {
                DirectBookingFinderView(property: property)
                    .presentationDetents([.large])
            }
        }
    }

    private func amenityIcon(for amenity: String) -> String {
        switch amenity.lowercased() {
        case "pool", "private pool": return "figure.pool.swim"
        case "wifi": return "wifi"
        case "bbq": return "flame.fill"
        case "parking": return "car.fill"
        case "ocean view": return "water.waves"
        case "air con": return "snowflake"
        case "fireplace": return "fireplace.fill"
        case "spa bath": return "bathtub.fill"
        case "deck", "balcony": return "rectangle.split.3x1"
        case "gym": return "dumbbell.fill"
        case "lift": return "arrow.up.arrow.down"
        case "garden", "tropical garden": return "leaf.fill"
        case "fire pit": return "flame"
        case "breakfast", "breakfast hamper": return "cup.and.saucer.fill"
        case "wine tasting": return "wineglass.fill"
        case "bushwalking", "bushwalk access": return "figure.hiking"
        case "surfboard storage": return "surfboard.fill"
        case "outdoor shower", "outdoor bath": return "drop.fill"
        case "stargazing roof": return "star.fill"
        default: return "checkmark.circle.fill"
        }
    }
}
