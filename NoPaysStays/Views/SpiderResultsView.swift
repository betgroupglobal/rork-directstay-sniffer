import SwiftUI

struct SpiderResultsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let criteria: SearchCriteria
    @State private var spider = SpiderCrawlerService()
    @State private var selectedFilter: ResultFilter = .all
    @State private var showLogs: Bool = false
    @State private var browserURL: URL?
    @State private var hapticTrigger: Int = 0
    @State private var showSaveSheet: Bool = false
    @State private var saveResult: CrawlResult?
    @State private var saveNotes: String = ""
    @State private var analysisTarget: AnalysisTarget?
    @State private var pulsePhase: Bool = false

    private var filteredResults: [CrawlResult] {
        switch selectedFilter {
        case .all:
            spider.results
        case .directOnly:
            spider.results.filter { $0.directBookingLikelihood == .high }
        case .withContact:
            spider.results.filter { $0.ownerContact != nil }
        case .lowFee:
            spider.results.filter { $0.feeIndicator == "0%" || $0.category == .directBooking }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                crawlStatusHeader
                filterBar

                if spider.results.isEmpty && spider.status.isActive {
                    crawlingPlaceholder
                } else if spider.results.isEmpty && !spider.status.isActive {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Spider Hunt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        spider.stopCrawl()
                        dismiss()
                    } label: {
                        Text("Done")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showLogs.toggle()
                        } label: {
                            Image(systemName: "terminal.fill")
                                .font(.subheadline)
                        }

                        if spider.status.isActive {
                            Button {
                                spider.stopCrawl()
                            } label: {
                                Image(systemName: "stop.circle.fill")
                                    .foregroundStyle(AppTheme.otaRed)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showLogs) {
                spiderLogSheet
            }
            .sheet(isPresented: $showSaveSheet) {
                saveSheet
            }
            .sheet(item: $analysisTarget) { target in
                PropertyAnalysisView(
                    url: target.url,
                    platformName: target.platformName,
                    location: criteria.location,
                    criteria: criteria
                )
            }
            .fullScreenCover(item: $browserURL) { url in
                SafariWebView(url: url) {
                    browserURL = nil
                }
                .ignoresSafeArea()
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
        .onAppear {
            spider.startCrawl(criteria: criteria)
        }
        .onDisappear {
            spider.stopCrawl()
        }
    }

    private var crawlStatusHeader: some View {
        VStack(spacing: 0) {
            switch spider.status {
            case .crawling(_, let progress):
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.quaternarySystemFill))
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.coral, AppTheme.burntOrange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress)
                            .animation(.spring(response: 0.4), value: progress)
                    }
                }
                .frame(height: 4)

                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.coral)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(spider.currentSource)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text("\(spider.crawledCount)/\(spider.totalSources) sources · \(spider.results.count) found")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(Int(progress * 100))%")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(AppTheme.coral)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))

            case .completed:
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.savingsGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hunt Complete")
                            .font(.caption.weight(.semibold))
                        Text("\(spider.results.count) results from \(spider.totalSources) sources")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        spider.startCrawl(criteria: criteria)
                        hapticTrigger += 1
                    } label: {
                        Label("Re-hunt", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(AppTheme.coral)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.savingsGreen.opacity(0.06))

            case .failed(let msg):
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.otaRed)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.otaRed.opacity(0.06))

            default:
                EmptyView()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ResultFilter.allCases, id: \.self) { filter in
                    let count = countForFilter(filter)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedFilter = filter
                        }
                        hapticTrigger += 1
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 10))
                            Text(filter.label)
                                .font(.caption.weight(.medium))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        selectedFilter == filter ? .white.opacity(0.3) : Color(.quaternarySystemFill),
                                        in: Capsule()
                                    )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            selectedFilter == filter
                                ? AppTheme.coral
                                : Color(.tertiarySystemGroupedBackground),
                            in: Capsule()
                        )
                        .foregroundStyle(selectedFilter == filter ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func countForFilter(_ filter: ResultFilter) -> Int {
        switch filter {
        case .all: spider.results.count
        case .directOnly: spider.results.filter { $0.directBookingLikelihood == .high }.count
        case .withContact: spider.results.filter { $0.ownerContact != nil }.count
        case .lowFee: spider.results.filter { $0.feeIndicator == "0%" || $0.category == .directBooking }.count
        }
    }

    private var crawlingPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "ant.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.coral)
                .symbolEffect(.pulse, options: .repeating)

            Text("Spider is crawling…")
                .font(.headline)

            Text("Results will appear here as they're discovered.\nThe spider searches \(spider.totalSources) sources in parallel.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        ContentUnavailableView(
            "No Results Found",
            systemImage: "magnifyingglass",
            description: Text("The spider couldn't extract listings from the crawled sources. Try adjusting your criteria or run again.")
        )
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredResults) { result in
                    resultCard(result)
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.spring(response: 0.35), value: filteredResults.map(\.id))
        }
    }

    private func resultCard(_ result: CrawlResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                likelihoodBadge(result.directBookingLikelihood)

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(result.sourcePlatform)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor(result.category), in: Capsule())

                        if result.feeIndicator == "0%" {
                            Text("NO FEE")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundStyle(AppTheme.savingsGreen)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppTheme.savingsGreen.opacity(0.12), in: Capsule())
                        }

                        if let price = result.priceHint {
                            Text(price)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.burntOrange)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            if !result.snippet.isEmpty {
                Text(result.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let contact = result.ownerContact {
                HStack(spacing: 6) {
                    Image(systemName: contact.contains("@") ? "envelope.fill" : "phone.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.savingsGreen)
                    Text(contact)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.savingsGreen)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.savingsGreen.opacity(0.08), in: .rect(cornerRadius: 6))
            }

            HStack(spacing: 8) {
                Button {
                    hapticTrigger += 1
                    if let url = URL(string: result.url) {
                        browserURL = url
                    }
                } label: {
                    Label("Open", systemImage: "safari")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(AppTheme.coral)

                Button {
                    saveResult = result
                    saveNotes = ""
                    showSaveSheet = true
                } label: {
                    Label("Save", systemImage: "bookmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    analysisTarget = AnalysisTarget(
                        url: result.url,
                        platformName: result.sourcePlatform
                    )
                } label: {
                    Label("Analyze", systemImage: "brain.head.profile.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(AppTheme.dustyPurple)

                Spacer()

                Menu {
                    Button {
                        UIPasteboard.general.string = result.url
                        hapticTrigger += 1
                    } label: {
                        Label("Copy URL", systemImage: "doc.on.doc")
                    }
                    Button {
                        if let url = URL(string: result.url) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open in Safari", systemImage: "arrow.up.forward.app")
                    }
                    if let contact = result.ownerContact {
                        Button {
                            UIPasteboard.general.string = contact
                            hapticTrigger += 1
                        } label: {
                            Label("Copy Contact", systemImage: "person.crop.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func likelihoodBadge(_ likelihood: DirectBookingLikelihood) -> some View {
        let color: Color = switch likelihood {
        case .high: AppTheme.savingsGreen
        case .medium: AppTheme.warningAmber
        case .low: Color.secondary
        }

        return Image(systemName: likelihood.icon)
            .font(.title3)
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.12), in: .rect(cornerRadius: 8))
    }

    private func categoryColor(_ category: PlatformCategory) -> Color {
        switch category {
        case .directBooking: AppTheme.savingsGreen
        case .alternativePlatform: AppTheme.burntOrange
        case .classifieds: AppTheme.amber
        case .searchEngine: AppTheme.coral
        case .socialMedia: AppTheme.dustyPurple
        case .tourismDirectory: Color.blue
        }
    }

    private var spiderLogSheet: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(spider.logs) { log in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(logColor(log.level))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 5)

                                Text(log.message)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(logColor(log.level))

                                Spacer()

                                Text(log.timestamp, style: .time)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.quaternary)
                            }
                            .id(log.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: spider.logs.count) { _, _ in
                    if let last = spider.logs.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Spider Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { showLogs = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    private func logColor(_ level: SpiderLog.Level) -> Color {
        switch level {
        case .info: .primary
        case .success: AppTheme.savingsGreen
        case .warning: AppTheme.warningAmber
        case .error: AppTheme.otaRed
        }
    }

    private var saveSheet: some View {
        NavigationStack {
            Form {
                if let result = saveResult {
                    Section("Found Listing") {
                        LabeledContent("Title", value: result.title)
                        LabeledContent("Source", value: result.sourcePlatform)
                        LabeledContent("Direct Likelihood", value: result.directBookingLikelihood.label)
                    }
                    Section("Notes") {
                        TextField("Add notes…", text: $saveNotes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
            }
            .navigationTitle("Save Find")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSaveSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let result = saveResult {
                            let find = SavedFind(
                                title: result.title,
                                platform: result.sourcePlatform,
                                url: result.url,
                                notes: saveNotes,
                                pricePerNight: nil
                            )
                            viewModel.addSavedFind(find)
                            showSaveSheet = false
                            hapticTrigger += 1
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

enum ResultFilter: CaseIterable {
    case all, directOnly, withContact, lowFee

    var label: String {
        switch self {
        case .all: "All"
        case .directOnly: "Direct"
        case .withContact: "Has Contact"
        case .lowFee: "No Fee"
        }
    }

    var icon: String {
        switch self {
        case .all: "line.3.horizontal.decrease"
        case .directOnly: "checkmark.seal.fill"
        case .withContact: "person.fill"
        case .lowFee: "dollarsign.circle.fill"
        }
    }
}
