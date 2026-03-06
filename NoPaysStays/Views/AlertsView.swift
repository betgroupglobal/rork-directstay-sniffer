import SwiftUI

struct AlertsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedProperty: Property?
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.alerts.isEmpty {
                    ContentUnavailableView(
                        "No Alerts Yet",
                        systemImage: "bell.slash",
                        description: Text("Save a search to get notified when new direct-booking properties are discovered")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(viewModel.alerts.enumerated()), id: \.element.id) { index, alert in
                                Button {
                                    viewModel.markAlertRead(alert)
                                    selectedProperty = alert.property
                                } label: {
                                    AlertCardView(alert: alert)
                                }
                                .buttonStyle(.plain)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 15)
                                .animation(.spring(response: 0.4).delay(Double(index) * 0.05), value: appeared)
                            }
                        }
                        .padding()
                    }
                    .onAppear { appeared = true }
                }
            }
            .navigationTitle("Alerts")
            .toolbar {
                if !viewModel.alerts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Mark All Read") {
                            viewModel.markAllAlertsRead()
                        }
                        .font(.subheadline)
                    }
                }
            }
            .sheet(item: $selectedProperty) { property in
                PropertyDetailView(property: property)
            }
        }
    }
}

struct AlertCardView: View {
    let alert: PropertyAlert

    var body: some View {
        HStack(spacing: 12) {
            Color(.secondarySystemBackground)
                .frame(width: 72, height: 72)
                .overlay {
                    AsyncImage(url: URL(string: alert.property.imageURLs.first ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !alert.isRead {
                        Circle()
                            .fill(AppTheme.coral)
                            .frame(width: 8, height: 8)
                    }
                    Text(alert.property.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                Text("Found via \"\(alert.savedSearchName)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let savings = alert.savingsPercentage {
                        Text("Save \(savings)%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(AppTheme.savingsGreen, in: Capsule())
                    }

                    HStack(spacing: 3) {
                        Circle()
                            .fill(AppTheme.pinColor(for: alert.property.bookingStrength))
                            .frame(width: 6, height: 6)
                        Text(alert.property.bookingStrength.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(alert.discoveredAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let alt = alert.property.bestAlternativePrice {
                    Text("$\(Int(alt))")
                        .font(.headline)
                        .foregroundStyle(AppTheme.savingsGreen)
                } else {
                    Text("$\(Int(alert.property.otaPrice))")
                        .font(.headline)
                }
                Text("/night")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            alert.isRead ? Color(.secondarySystemBackground) : AppTheme.coral.opacity(0.05)
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(alert.isRead ? .clear : AppTheme.coral.opacity(0.15), lineWidth: 1)
        )
    }
}
