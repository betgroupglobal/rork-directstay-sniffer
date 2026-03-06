import SwiftUI

struct PropertyAnalysisView: View {
    let url: String
    let platformName: String
    let location: String
    let criteria: SearchCriteria?

    @Environment(\.dismiss) private var dismiss
    @State private var analysis: PropertyAnalysis?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var revealedSections: Set<AnalysisSection> = []
    @State private var hapticTrigger: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard

                    if isLoading {
                        loadingState
                    } else if let error = errorMessage {
                        errorState(error)
                    } else if let analysis {
                        scoreCard(analysis)
                        sectionCard(
                            section: .offerings,
                            icon: "house.lodge.fill",
                            title: "Property Offerings",
                            content: analysis.propertyOfferings,
                            color: AppTheme.burntOrange
                        )
                        sectionCard(
                            section: .business,
                            icon: "building.2.fill",
                            title: "Business & Domain",
                            content: analysis.businessPresence,
                            color: AppTheme.dustyPurple
                        )
                        sectionCard(
                            section: .reviews,
                            icon: "star.bubble.fill",
                            title: "Reviews & Reputation",
                            content: analysis.reviewsSummary,
                            color: AppTheme.amber
                        )
                        sectionCard(
                            section: .payment,
                            icon: "creditcard.fill",
                            title: "Payment Methods",
                            content: analysis.paymentMethods,
                            color: AppTheme.savingsGreen
                        )
                        insightsCard(analysis)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if analysis != nil {
                        ShareLink(item: buildShareText()) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
        .task {
            await runAnalysis()
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.coral, AppTheme.burntOrange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "brain.head.profile.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(platformName)
                    .font(.subheadline.weight(.semibold))
                Text(location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(url)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var loadingState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.coral.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.coral)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 6) {
                Text("Analyzing Property")
                    .font(.headline)
                Text("AI is reviewing the platform, URL structure, and listing context to generate insights...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            ProgressView()
                .tint(AppTheme.coral)
        }
        .padding(.vertical, 60)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.warningAmber)

            Text("Analysis Failed")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                hapticTrigger += 1
                Task { await runAnalysis() }
            } label: {
                Label("Retry Analysis", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.coral, in: Capsule())
            }
        }
        .padding(.vertical, 40)
    }

    private func scoreCard(_ analysis: PropertyAnalysis) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color(.quaternarySystemFill), lineWidth: 6)
                        .frame(width: 64, height: 64)

                    Circle()
                        .trim(from: 0, to: CGFloat(analysis.directBookingScore) / 10.0)
                        .stroke(
                            scoreColor(analysis.directBookingScore),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))

                    Text("\(analysis.directBookingScore)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(scoreColor(analysis.directBookingScore))
                }

                Text("Direct Score")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(scoreLabel(analysis.directBookingScore))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(scoreColor(analysis.directBookingScore))

                Text(scoreDescription(analysis.directBookingScore))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func sectionCard(
        section: AnalysisSection,
        icon: String,
        title: String,
        content: String,
        color: Color
    ) -> some View {
        let isExpanded = revealedSections.contains(section)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    if isExpanded {
                        revealedSections.remove(section)
                    } else {
                        revealedSections.insert(section)
                        hapticTrigger += 1
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(color)
                        .frame(width: 28, height: 28)
                        .background(color.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 7))

                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(14)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)

                Text(content.isEmpty ? "No data available for this section." : content)
                    .font(.subheadline)
                    .foregroundStyle(content.isEmpty ? .tertiary : .primary)
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
        .onAppear {
            if analysis != nil && revealedSections.isEmpty {
                revealedSections = Set(AnalysisSection.allCases)
            }
        }
    }

    private func insightsCard(_ analysis: PropertyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppTheme.amber)
                Text("Key Insights")
                    .font(.subheadline.weight(.semibold))
            }

            ForEach(Array(analysis.keyInsights.enumerated()), id: \.offset) { index, insight in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(AppTheme.coral, in: Circle())

                    Text(insight)
                        .font(.subheadline)
                        .lineSpacing(3)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func runAnalysis() async {
        isLoading = true
        errorMessage = nil
        do {
            analysis = try await AIAnalysisService.analyzeProperty(
                url: url,
                platformName: platformName,
                location: location,
                criteria: criteria
            )
            hapticTrigger += 1
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 8 { return AppTheme.savingsGreen }
        if score >= 5 { return AppTheme.amber }
        return AppTheme.otaRed
    }

    private func scoreLabel(_ score: Int) -> String {
        if score >= 8 { return "High Direct Potential" }
        if score >= 5 { return "Moderate Potential" }
        return "Low Direct Potential"
    }

    private func scoreDescription(_ score: Int) -> String {
        if score >= 8 { return "This source is very likely to lead to a direct booking with no or minimal fees." }
        if score >= 5 { return "There's a reasonable chance of finding a direct booking option through this source." }
        return "This source primarily operates through OTA-style fees, but may have useful owner info."
    }

    private func buildShareText() -> String {
        guard let a = analysis else { return "" }
        return """
        NoPays Stays — AI Analysis
        Platform: \(platformName)
        Location: \(location)
        Direct Booking Score: \(a.directBookingScore)/10

        Property Offerings:
        \(a.propertyOfferings)

        Business Presence:
        \(a.businessPresence)

        Reviews:
        \(a.reviewsSummary)

        Payment:
        \(a.paymentMethods)

        Key Insights:
        \(a.keyInsights.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """
    }
}

enum AnalysisSection: CaseIterable {
    case offerings
    case business
    case reviews
    case payment
}
