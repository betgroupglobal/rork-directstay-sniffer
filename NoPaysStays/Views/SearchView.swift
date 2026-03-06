import SwiftUI
import MapKit

struct SearchView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var locationQuery: String = ""
    @State private var checkIn: Date = Date()
    @State private var checkOut: Date = Date().addingTimeInterval(86400 * 7)
    @State private var guests: Int = 2
    @State private var petFriendly: Bool = false
    @State private var directOnly: Bool = false
    @State private var selectedTypes: Set<PropertyType> = []
    @State private var searchCompleter = LocationSearchCompleter()
    @State private var showResults: Bool = false
    @State private var animateGradient: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    meshGradientHeader
                    searchForm
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var meshGradientHeader: some View {
        ZStack {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [animateGradient ? 0.6 : 0.4, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    AppTheme.peach, AppTheme.coral, AppTheme.burntOrange,
                    AppTheme.coral, AppTheme.amber, AppTheme.dustyPurple.opacity(0.7),
                    AppTheme.burntOrange, AppTheme.dustyPurple.opacity(0.5), AppTheme.peach
                ]
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    animateGradient = true
                }
            }

            VStack(spacing: 12) {
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.9))

                Text("Find Your Perfect Stay")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)

                Text("Skip the fees. Book direct.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .frame(height: 200)
    }

    private var searchForm: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Location", systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.burntOrange)

                TextField("Byron Bay, Noosa, Margaret River...", text: $locationQuery)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: locationQuery) { _, newValue in
                        searchCompleter.search(newValue)
                    }

                if !searchCompleter.results.isEmpty && !locationQuery.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(searchCompleter.results.prefix(5), id: \.self) { result in
                            Button {
                                locationQuery = result.title
                                searchCompleter.results = []
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(AppTheme.coral)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(result.title)
                                            .font(.subheadline)
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Dates", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.burntOrange)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check In")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $checkIn, displayedComponents: .date)
                            .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check Out")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $checkOut, in: checkIn..., displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Guests", systemImage: "person.2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.burntOrange)

                Stepper("\(guests) Guest\(guests == 1 ? "" : "s")", value: $guests, in: 1...20)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Filters", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.burntOrange)

                Toggle(isOn: $petFriendly) {
                    Label("Pet Friendly", systemImage: "pawprint.fill")
                }
                .tint(AppTheme.burntOrange)

                Toggle(isOn: $directOnly) {
                    Label("Direct Booking Only", systemImage: "checkmark.seal.fill")
                }
                .tint(AppTheme.savingsGreen)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text("Property Type")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.burntOrange)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(PropertyType.allCases, id: \.self) { type in
                        Button {
                            if selectedTypes.contains(type) {
                                selectedTypes.remove(type)
                            } else {
                                selectedTypes.insert(type)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.caption2)
                                Text(type.label)
                                    .font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(selectedTypes.contains(type) ? AppTheme.burntOrange : Color(.tertiarySystemGroupedBackground))
                            .foregroundStyle(selectedTypes.contains(type) ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            Button {
                viewModel.filterPetFriendly = petFriendly
                viewModel.filterDirectOnly = directOnly
                viewModel.filterMinGuests = guests
                viewModel.filterPropertyTypes = selectedTypes
                if !locationQuery.isEmpty {
                    viewModel.searchText = locationQuery
                }
                showResults = true
                Task {
                    await viewModel.searchAPI(
                        location: locationQuery,
                        checkIn: checkIn,
                        checkOut: checkOut,
                        guests: guests,
                        petFriendly: petFriendly
                    )
                }
            } label: {
                Label("Search Properties", systemImage: "magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [AppTheme.coral, AppTheme.burntOrange], startPoint: .leading, endPoint: .trailing),
                        in: .rect(cornerRadius: 14)
                    )
            }
            .padding(.top, 4)
        }
        .padding(20)
        .sheet(isPresented: $showResults) {
            SearchResultsView()
        }
    }
}

struct SearchResultsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProperty: Property?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Crawling for direct stays...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("This may take a moment")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Search Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Dismiss") { dismiss() }
                            .buttonStyle(.bordered)
                    }
                } else {
                    resultsContent
                }
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedProperty) { property in
                PropertyDetailView(property: property)
            }
        }
    }

    private var resultsContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !viewModel.airbnbResults.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                            .foregroundStyle(AppTheme.coral)
                        Text("\(viewModel.airbnbResults.count) Airbnb Listings")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("Tap to find direct")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 4)

                    ForEach(viewModel.airbnbResults) { property in
                        Button {
                            selectedProperty = property
                        } label: {
                            AirbnbResultCard(property: property)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !viewModel.searchResults.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(AppTheme.savingsGreen)
                        Text("\(viewModel.searchResults.count) Direct Stays Found")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .padding(.top, viewModel.airbnbResults.isEmpty ? 0 : 8)
                    .padding(.bottom, 4)

                    ForEach(viewModel.searchResults) { property in
                        Button {
                            selectedProperty = property
                        } label: {
                            CrawlResultCard(property: property)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !viewModel.filteredProperties.isEmpty {
                    if !viewModel.searchResults.isEmpty || !viewModel.airbnbResults.isEmpty {
                        HStack {
                            Text("Local Results")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.top, 8)
                    }

                    ForEach(viewModel.filteredProperties) { property in
                        Button {
                            selectedProperty = property
                        } label: {
                            PropertyCardView(
                                property: property,
                                isFavorite: viewModel.isFavorite(property),
                                onFavorite: { viewModel.toggleFavorite(property) }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.searchResults.isEmpty && viewModel.airbnbResults.isEmpty && viewModel.filteredProperties.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No properties match your criteria")
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
    }
}

struct CrawlResultCard: View {
    let property: Property

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.burntOrange.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: property.bookingStrength == .direct ? "checkmark.seal.fill" : "link")
                        .font(.title3)
                        .foregroundStyle(property.bookingStrength == .direct ? AppTheme.savingsGreen : AppTheme.burntOrange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(property.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !property.subtitle.isEmpty {
                        Text(property.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        if let link = property.bookingLinks.first {
                            Text(link.platform)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())

                            if link.isDirectBooking {
                                Text("DIRECT")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.savingsGreen, in: Capsule())
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }
}

struct AirbnbResultCard: View {
    let property: Property

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let imageURL = property.imageURLs.first, let url = URL(string: imageURL) {
                Color(.secondarySystemBackground)
                    .frame(width: 72, height: 72)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(systemName: "photo")
                                    .foregroundStyle(.tertiary)
                            } else {
                                ProgressView()
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.coral.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Image(systemName: "house.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.coral)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(property.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !property.subtitle.isEmpty {
                    Text(property.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if property.bedrooms > 0 {
                        Label("\(property.bedrooms)", systemImage: "bed.double.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if property.maxGuests > 0 {
                        Label("\(property.maxGuests)", systemImage: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 6) {
                    if property.otaPrice > 0 {
                        Text("$\(Int(property.otaPrice))/night")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.burntOrange)
                    }

                    Text("AIRBNB")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.coral, in: Capsule())

                    Spacer()

                    Text("Find Direct")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.savingsGreen)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.savingsGreen)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }
}

@Observable
class LocationSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -25.0, longitude: 134.0),
            span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
        )
    }

    func search(_ query: String) {
        completer.queryFragment = query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}
