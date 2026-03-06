import SwiftUI
import MapKit

struct ExploreView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -28.65, longitude: 153.6),
            span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
        )
    )
    @State private var selectedDetent: PresentationDetent = .fraction(0.4)
    @State private var showSheet: Bool = true
    @State private var selectedPropertyForDetail: Property?
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(viewModel.filteredProperties) { property in
                    Annotation(property.title, coordinate: property.coordinate) {
                        PropertyPinView(property: property)
                            .onTapGesture {
                                selectedPropertyForDetail = property
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea(edges: .top)
            .sheet(isPresented: $showSheet) {
                ExploreSheetContent(onSelect: { property in
                    selectedPropertyForDetail = property
                })
                .presentationDetents([.fraction(0.15), .fraction(0.4), .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.4)))
                .presentationContentInteraction(.scrolls)
                .presentationCornerRadius(20)
                .interactiveDismissDisabled()
            }
            .sheet(item: $selectedPropertyForDetail) { property in
                PropertyDetailView(property: property)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Explore")
                        .font(.title2.weight(.bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: .capsule)
                }
            }
        }
    }
}

struct ExploreSheetContent: View {
    @Environment(AppViewModel.self) private var viewModel
    let onSelect: (Property) -> Void
    @State private var hapticTrigger: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                filterChips

                ForEach(viewModel.filteredProperties) { property in
                    Button {
                        onSelect(property)
                    } label: {
                        PropertyCardView(
                            property: property,
                            isFavorite: viewModel.isFavorite(property),
                            onFavorite: {
                                viewModel.toggleFavorite(property)
                                hapticTrigger += 1
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.filteredProperties.isEmpty {
                    ContentUnavailableView(
                        "No Properties Found",
                        systemImage: "house.slash",
                        description: Text("Try adjusting your filters or search area")
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: "Direct Only", isActive: viewModel.filterDirectOnly) {
                    viewModel.filterDirectOnly.toggle()
                }
                FilterChip(title: "Pet Friendly", icon: "pawprint.fill", isActive: viewModel.filterPetFriendly) {
                    viewModel.filterPetFriendly.toggle()
                }
                ForEach(PropertyType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.label,
                        icon: type.icon,
                        isActive: viewModel.filterPropertyTypes.contains(type)
                    ) {
                        if viewModel.filterPropertyTypes.contains(type) {
                            viewModel.filterPropertyTypes.remove(type)
                        } else {
                            viewModel.filterPropertyTypes.insert(type)
                        }
                    }
                }
                if viewModel.filterDirectOnly || viewModel.filterPetFriendly || !viewModel.filterPropertyTypes.isEmpty {
                    Button {
                        viewModel.clearFilters()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }
}

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isActive ? AppTheme.burntOrange : Color(.tertiarySystemBackground))
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct PropertyPinView: View {
    let property: Property

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(AppTheme.pinColor(for: property.bookingStrength))
                    .frame(width: 36, height: 36)
                    .shadow(color: AppTheme.pinColor(for: property.bookingStrength).opacity(0.5), radius: 4, y: 2)
                Image(systemName: property.propertyType.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(AppTheme.pinColor(for: property.bookingStrength))
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
    }
}
