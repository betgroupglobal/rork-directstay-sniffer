import SwiftUI
import MapKit

struct SearchView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var locationQuery: String = ""
    @State private var checkIn: Date = Date()
    @State private var checkOut: Date = Date().addingTimeInterval(86400 * 7)
    @State private var guests: Int = 2
    @State private var bedrooms: Int = 1
    @State private var bathrooms: Int = 1
    @State private var petFriendly: Bool = false
    @State private var wholeHome: Bool = true
    @State private var maxPrice: String = ""
    @State private var radius: Int = 25
    @State private var useDates: Bool = true
    @State private var searchCompleter = LocationSearchCompleter()
    @State private var showResults: Bool = false
    @State private var animateGradient: Bool = false
    @State private var hapticTrigger: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    meshGradientHeader
                    searchForm
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("NoPays Stays")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showResults) {
                SearchResultsView()
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
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

            VStack(spacing: 8) {
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.95))
                    .symbolEffect(.pulse, options: .repeating.speed(0.3))

                Text("Find Direct Bookings")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Skip the 15-20% OTA fees — the app hunts\n\(searchLinkCount) sources for you automatically")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .frame(height: 175)
    }

    private var searchLinkCount: Int {
        let test = SearchCriteria(location: "test", isPetFriendly: petFriendly)
        return DeepSearchService.generateSearchLinks(for: test).count
    }

    private var searchForm: some View {
        VStack(spacing: 20) {
            locationSection
            dateSection
            guestRoomSection
            filtersSection
            searchButton
        }
        .padding(20)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Where are you going?", systemImage: "mappin.and.ellipse")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.burntOrange)

            TextField("Byron Bay, Noosa, Margaret River...", text: $locationQuery)
                .textFieldStyle(.roundedBorder)
                .textContentType(.addressCity)
                .onChange(of: locationQuery) { _, newValue in
                    searchCompleter.search(newValue)
                }

            if !searchCompleter.results.isEmpty && !locationQuery.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchCompleter.results.prefix(5), id: \.self) { result in
                        Button {
                            locationQuery = [result.title, result.subtitle]
                                .filter { !$0.isEmpty }
                                .joined(separator: ", ")
                            searchCompleter.results = []
                        } label: {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(AppTheme.coral)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(result.title)
                                        .font(.subheadline)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
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
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Dates", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.burntOrange)
                Spacer()
                Toggle("", isOn: $useDates)
                    .labelsHidden()
                    .tint(AppTheme.burntOrange)
            }

            if useDates {
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
            } else {
                Text("Flexible dates — platforms will show all availability")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
    }

    private var guestRoomSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Guests", systemImage: "person.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.burntOrange)
                    Stepper("\(guests)", value: $guests, in: 1...20)
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Bedrooms", systemImage: "bed.double.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.burntOrange)
                    Stepper("\(bedrooms)", value: $bedrooms, in: 1...10)
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: 10))
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Bathrooms", systemImage: "shower.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.burntOrange)
                    Stepper("\(bathrooms)", value: $bathrooms, in: 1...10)
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Radius", systemImage: "circle.dashed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.burntOrange)
                    Stepper("\(radius)km", value: $radius, in: 5...200, step: 5)
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Filters", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.burntOrange)

            Toggle(isOn: $petFriendly) {
                Label("Pet Friendly", systemImage: "pawprint.fill")
            }
            .tint(AppTheme.burntOrange)

            Toggle(isOn: $wholeHome) {
                Label("Whole Home Only", systemImage: "house.fill")
            }
            .tint(AppTheme.burntOrange)

            HStack {
                Label("Max Price/Night", systemImage: "dollarsign.circle.fill")
                    .font(.subheadline)
                Spacer()
                TextField("Any", text: $maxPrice)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var searchButton: some View {
        Button {
            hapticTrigger += 1
            viewModel.currentCriteria = SearchCriteria(
                location: locationQuery,
                checkIn: useDates ? checkIn : nil,
                checkOut: useDates ? checkOut : nil,
                guests: guests,
                bedrooms: bedrooms,
                bathrooms: bathrooms,
                isPetFriendly: petFriendly,
                isWholeHome: wholeHome,
                maxPricePerNight: Int(maxPrice),
                radiusKm: radius
            )
            viewModel.performSearch()
            showResults = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "binoculars.fill")
                    .font(.headline)
                VStack(spacing: 2) {
                    Text("Hunt Direct Bookings")
                        .font(.headline)
                    Text("\(searchLinkCount) sources · auto-opens each in-app")
                        .font(.caption2)
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [AppTheme.coral, AppTheme.burntOrange], startPoint: .leading, endPoint: .trailing),
                in: .rect(cornerRadius: 14)
            )
        }
        .disabled(locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        .padding(.top, 4)
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
