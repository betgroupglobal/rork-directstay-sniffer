import SwiftUI

struct SearchResultsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var expandedCategories: Set<PlatformCategory> = Set(PlatformCategory.allCases)
    @State private var showSaveSheet: Bool = false
    @State private var saveURL: String = ""
    @State private var saveTitle: String = ""
    @State private var savePlatform: String = ""
    @State private var hapticTrigger: Int = 0
    @State private var browserURL: URL?
    @State private var currentBrowserLinkID: String?
    @State private var huntIndex: Int = 0
    @State private var isHunting: Bool = false

    private var prioritizedResults: [PlatformSearch] {
        viewModel.searchResults.sorted { a, b in
            if a.category.sortOrder != b.category.sortOrder {
                return a.category.sortOrder < b.category.sortOrder
            }
            return false
        }
    }

    private var uncheckedCount: Int {
        viewModel.searchResults.filter { !viewModel.checkedLinks.contains($0.id) }.count
    }

    private var checkedCount: Int {
        viewModel.checkedLinks.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                huntProgressBar

                ScrollView {
                    VStack(spacing: 16) {
                        searchSummaryCard
                        huntControlCard

                        if viewModel.searchResults.isEmpty {
                            ContentUnavailableView(
                                "No Results",
                                systemImage: "magnifyingglass",
                                description: Text("Try a different location")
                            )
                            .padding(.top, 40)
                        } else {
                            ForEach(viewModel.resultsByCategory, id: \.0) { category, links in
                                categorySection(category: category, links: links)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Hunt Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            expandedCategories = Set(PlatformCategory.allCases)
                        } label: {
                            Label("Expand All", systemImage: "rectangle.expand.vertical")
                        }
                        Button {
                            expandedCategories.removeAll()
                        } label: {
                            Label("Collapse All", systemImage: "rectangle.compress.vertical")
                        }
                        Divider()
                        Button {
                            viewModel.clearCheckedLinks()
                        } label: {
                            Label("Reset Progress", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showSaveSheet) {
                saveFindsSheet
            }
            .fullScreenCover(item: $browserURL) { url in
                SafariWebView(url: url) {
                    if let linkID = currentBrowserLinkID {
                        viewModel.markLinkChecked(linkID)
                    }
                    browserURL = nil
                    currentBrowserLinkID = nil

                    if isHunting {
                        advanceHunt()
                    }
                }
                .ignoresSafeArea()
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
    }

    private var huntProgressBar: some View {
        GeometryReader { geo in
            let total = viewModel.searchResults.count
            let progress = total > 0 ? CGFloat(checkedCount) / CGFloat(total) : 0

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.quaternarySystemFill))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.savingsGreen, AppTheme.savingsGreen.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(response: 0.4), value: progress)
            }
        }
        .frame(height: 4)
    }

    private var searchSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(AppTheme.coral)
                Text(viewModel.currentCriteria.location)
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Text("\(checkedCount)/\(viewModel.searchResults.count)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
                .foregroundStyle(checkedCount == viewModel.searchResults.count && checkedCount > 0 ? AppTheme.savingsGreen : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    (checkedCount == viewModel.searchResults.count && checkedCount > 0 ? AppTheme.savingsGreen : Color.secondary).opacity(0.12),
                    in: Capsule()
                )
            }

            HStack(spacing: 12) {
                Label("\(viewModel.currentCriteria.guests)", systemImage: "person.2.fill")
                Label("\(viewModel.currentCriteria.bedrooms) bed", systemImage: "bed.double.fill")
                Label("\(viewModel.currentCriteria.bathrooms) bath", systemImage: "shower.fill")
                if viewModel.currentCriteria.isPetFriendly {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(AppTheme.burntOrange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(viewModel.currentCriteria.dateRangeText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var huntControlCard: some View {
        VStack(spacing: 12) {
            if uncheckedCount > 0 {
                Button {
                    hapticTrigger += 1
                    startHunt()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isHunting ? "stop.circle.fill" : "binoculars.fill")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isHunting ? "Hunting — Close Browser to Continue" : "Start Auto-Hunt")
                                .font(.subheadline.weight(.semibold))
                            Text(isHunting
                                 ? "Check each page, close when done to advance"
                                 : "\(uncheckedCount) unchecked sources · opens each in-app")
                                .font(.caption2)
                                .opacity(0.85)
                        }
                        Spacer()
                        if !isHunting {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .opacity(0.6)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: isHunting ? [AppTheme.savingsGreen, AppTheme.savingsGreen.opacity(0.8)] : [AppTheme.coral, AppTheme.burntOrange],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: .rect(cornerRadius: 14)
                    )
                }
            } else if !viewModel.searchResults.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.savingsGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Sources Checked")
                            .font(.subheadline.weight(.semibold))
                        Text("You've reviewed every platform for \(viewModel.currentCriteria.location)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(AppTheme.savingsGreen.opacity(0.08))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(AppTheme.savingsGreen.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private func startHunt() {
        let unchecked = prioritizedResults.filter { !viewModel.checkedLinks.contains($0.id) }
        guard let first = unchecked.first else { return }
        isHunting = true
        huntIndex = prioritizedResults.firstIndex(where: { $0.id == first.id }) ?? 0
        openLink(first)
    }

    private func advanceHunt() {
        let remaining = prioritizedResults.filter { !viewModel.checkedLinks.contains($0.id) }
        if let next = remaining.first {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                openLink(next)
            }
        } else {
            isHunting = false
            hapticTrigger += 1
        }
    }

    private func openLink(_ link: PlatformSearch) {
        currentBrowserLinkID = link.id
        browserURL = link.searchURL
    }

    private func categorySection(category: PlatformCategory, links: [PlatformSearch]) -> some View {
        let checkedInCategory = links.filter { viewModel.checkedLinks.contains($0.id) }.count

        return VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    if expandedCategories.contains(category) {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.subheadline)
                        .foregroundStyle(categoryColor(category))
                        .frame(width: 24)
                    Text(category.label)
                        .font(.subheadline.weight(.semibold))

                    Text("\(checkedInCategory)/\(links.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            checkedInCategory == links.count
                            ? AppTheme.savingsGreen.opacity(0.9)
                            : categoryColor(category).opacity(0.8),
                            in: Capsule()
                        )

                    Spacer()
                    Image(systemName: expandedCategories.contains(category) ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if expandedCategories.contains(category) {
                VStack(spacing: 1) {
                    ForEach(links) { link in
                        platformLinkRow(link)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func platformLinkRow(_ link: PlatformSearch) -> some View {
        let isChecked = viewModel.checkedLinks.contains(link.id)

        return HStack(spacing: 12) {
            ZStack {
                Image(systemName: link.icon)
                    .font(.subheadline)
                    .foregroundStyle(isChecked ? .secondary : categoryColor(link.category))
                    .frame(width: 28, height: 28)
                    .background(
                        isChecked
                        ? Color(.quaternarySystemFill)
                        : categoryColor(link.category).opacity(0.12)
                    )
                    .clipShape(.rect(cornerRadius: 7))

                if isChecked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.savingsGreen)
                        .background(.white, in: Circle())
                        .offset(x: 10, y: -10)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(link.platformName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isChecked ? .secondary : .primary)
                Text(link.description)
                    .font(.caption2)
                    .foregroundStyle(isChecked ? .quaternary : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let fee = link.feePercentage {
                Text(fee)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(fee == "0%" ? AppTheme.savingsGreen : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        fee == "0%" ? AppTheme.savingsGreen.opacity(0.1) : Color(.tertiarySystemBackground)
                    )
                    .clipShape(Capsule())
            }

            Menu {
                Button {
                    openLink(link)
                } label: {
                    Label("Open In-App", systemImage: "safari")
                }
                Button {
                    UIApplication.shared.open(link.searchURL)
                    viewModel.markLinkChecked(link.id)
                } label: {
                    Label("Open in Safari", systemImage: "arrow.up.forward.app")
                }
                Divider()
                Button {
                    saveURL = link.searchURL.absoluteString
                    saveTitle = "\(link.platformName) — \(viewModel.currentCriteria.location)"
                    savePlatform = link.platformName
                    showSaveSheet = true
                } label: {
                    Label("Save This Find", systemImage: "bookmark")
                }
                Button {
                    UIPasteboard.general.url = link.searchURL
                    hapticTrigger += 1
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
                Divider()
                if isChecked {
                    Button {
                        viewModel.unmarkLinkChecked(link.id)
                    } label: {
                        Label("Mark Unchecked", systemImage: "arrow.uturn.backward")
                    }
                } else {
                    Button {
                        viewModel.markLinkChecked(link.id)
                        hapticTrigger += 1
                    } label: {
                        Label("Mark as Checked", systemImage: "checkmark.circle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                hapticTrigger += 1
                openLink(link)
            } label: {
                Image(systemName: "arrow.up.right.square.fill")
                    .font(.title3)
                    .foregroundStyle(isChecked ? .secondary : categoryColor(link.category))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .opacity(isChecked ? 0.7 : 1)
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

    private var saveFindsSheet: some View {
        NavigationStack {
            Form {
                Section("Link Details") {
                    TextField("Title", text: $saveTitle)
                    TextField("Platform", text: $savePlatform)
                    TextField("URL", text: $saveURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
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
                        let find = SavedFind(
                            title: saveTitle,
                            platform: savePlatform,
                            url: saveURL
                        )
                        viewModel.addSavedFind(find)
                        showSaveSheet = false
                        hapticTrigger += 1
                    }
                    .disabled(saveTitle.isEmpty || saveURL.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
