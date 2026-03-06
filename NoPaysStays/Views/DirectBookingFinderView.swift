import SwiftUI

struct DirectBookingFinderView: View {
    let property: Property
    @State private var results: [BookingHit] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?
    @State private var searchQueries: [String] = []
    @State private var currentQueryIndex: Int = 0
    @State private var hasSearched: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    if isSearching {
                        searchingState
                    } else if let error = errorMessage {
                        errorState(error)
                    } else if hasSearched {
                        resultsSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Find Direct Booking")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await performLookup()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.coral.opacity(0.15), AppTheme.burntOrange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.coral)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(property.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    let loc = [property.suburb, property.state].filter { !$0.isEmpty }.joined(separator: ", ")
                    if !loc.isEmpty {
                        Text(loc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Search Strategy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                searchStrategyRow(icon: "textformat", label: "Property name lookup")
                if property.ownerContact?.name != nil {
                    searchStrategyRow(icon: "person.fill", label: "Owner/host name search")
                }
                if !property.address.isEmpty || !property.suburb.isEmpty {
                    searchStrategyRow(icon: "mappin", label: "Address & location search")
                }
                searchStrategyRow(icon: "globe", label: "Direct booking site discovery")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func searchStrategyRow(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.burntOrange)
                .frame(width: 18)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var searchingState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.coral.opacity(0.1))
                    .frame(width: 80, height: 80)
                ProgressView()
                    .controlSize(.large)
                    .tint(AppTheme.coral)
            }

            VStack(spacing: 6) {
                Text("Searching the web...")
                    .font(.headline)
                Text("Looking for direct booking sites, owner websites, and alternative platforms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.warningAmber)
            Text("Search encountered an issue")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await performLookup() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.coral)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var resultsSection: some View {
        VStack(spacing: 12) {
            let directHits = results.filter { isDirectHit($0) }
            let otherHits = results.filter { !isDirectHit($0) }

            if directHits.isEmpty && otherHits.isEmpty {
                emptyState
            } else {
                if !directHits.isEmpty {
                    sectionHeader(
                        title: "Direct Booking Sites",
                        count: directHits.count,
                        icon: "checkmark.seal.fill",
                        color: AppTheme.savingsGreen
                    )
                    ForEach(Array(directHits.enumerated()), id: \.element.id) { index, hit in
                        DirectHitCard(hit: hit, isDirect: true, rank: index + 1)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                if !otherHits.isEmpty {
                    sectionHeader(
                        title: "Other Results",
                        count: otherHits.count,
                        icon: "link.circle.fill",
                        color: AppTheme.burntOrange
                    )
                    .padding(.top, directHits.isEmpty ? 0 : 8)

                    ForEach(Array(otherHits.prefix(15).enumerated()), id: \.element.id) { index, hit in
                        DirectHitCard(hit: hit, isDirect: false, rank: index + 1)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text("(\(count))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe.desk")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No direct sites found yet")
                .font(.headline)
            Text("We couldn't find a direct booking website for this property. The owner may only list on OTA platforms.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                let query = "\(property.title) \(property.suburb) direct booking"
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "https://duckduckgo.com/?q=\(query)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Search Manually", systemImage: "safari")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.burntOrange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func isDirectHit(_ hit: BookingHit) -> Bool {
        let url = hit.booking_url.lowercased()
        let otaDomains = ["airbnb.com", "booking.com", "stayz.com", "expedia.com", "vrbo.com", "hotels.com", "agoda.com", "tripadvisor.com"]
        return !otaDomains.contains(where: { url.contains($0) })
    }

    private func performLookup() async {
        isSearching = true
        errorMessage = nil
        hasSearched = false

        do {
            let hits = try await APIService.shared.lookupDirectBooking(for: property)
            withAnimation(.spring(duration: 0.4)) {
                results = hits
                hasSearched = true
            }
        } catch {
            errorMessage = error.localizedDescription
            hasSearched = true
        }

        isSearching = false
    }
}

struct DirectHitCard: View {
    let hit: BookingHit
    let isDirect: Bool
    let rank: Int

    var body: some View {
        Button {
            if let url = URL(string: hit.booking_url) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isDirect ? AppTheme.savingsGreen.opacity(0.12) : Color(.tertiarySystemBackground))
                        .frame(width: 44, height: 44)
                    Image(systemName: isDirect ? "checkmark.seal.fill" : "link")
                        .font(.body)
                        .foregroundStyle(isDirect ? AppTheme.savingsGreen : AppTheme.burntOrange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(hit.title.isEmpty ? domainName : hit.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)

                    Text(domainName)
                        .font(.caption)
                        .foregroundStyle(isDirect ? AppTheme.savingsGreen : .secondary)

                    if !hit.snippet.isEmpty {
                        Text(hit.snippet)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        if !hit.matched_terms.isEmpty {
                            ForEach(hit.matched_terms.prefix(3), id: \.self) { term in
                                Text(term)
                                    .font(.system(size: 9, weight: .medium))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color(.quaternarySystemFill))
                                    .clipShape(Capsule())
                            }
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Text("relevance")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            ScoreBar(score: hit.score)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right.circle")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var domainName: String {
        URL(string: hit.booking_url)?.host?.replacingOccurrences(of: "www.", with: "") ?? hit.source
    }
}

struct ScoreBar: View {
    let score: Double

    var body: some View {
        let normalizedScore = min(score / 10.0, 1.0)
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Double(i) / 5.0 < normalizedScore ? AppTheme.savingsGreen : Color(.quaternarySystemFill))
                    .frame(width: 4, height: 8)
            }
        }
    }
}
