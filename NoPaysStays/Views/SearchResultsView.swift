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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    searchSummaryCard

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
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Results")
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
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showSaveSheet) {
                saveFindsSheet
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
    }

    private var searchSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(AppTheme.coral)
                Text(viewModel.currentCriteria.location)
                    .font(.headline)
                Spacer()
                Text("\(viewModel.searchResults.count) links")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.burntOrange, in: Capsule())
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

    private func categorySection(category: PlatformCategory, links: [PlatformSearch]) -> some View {
        VStack(spacing: 0) {
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
                    Text("\(links.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryColor(category).opacity(0.8), in: Capsule())
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
        HStack(spacing: 12) {
            Image(systemName: link.icon)
                .font(.subheadline)
                .foregroundStyle(categoryColor(link.category))
                .frame(width: 28, height: 28)
                .background(categoryColor(link.category).opacity(0.12))
                .clipShape(.rect(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(link.platformName)
                    .font(.subheadline.weight(.medium))
                Text(link.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                    UIApplication.shared.open(link.searchURL)
                } label: {
                    Label("Open in Safari", systemImage: "safari")
                }
                Button {
                    saveURL = link.searchURL.absoluteString
                    saveTitle = "\(link.platformName) — \(viewModel.currentCriteria.location)"
                    savePlatform = link.platformName
                    showSaveSheet = true
                } label: {
                    Label("Save This Link", systemImage: "bookmark")
                }
                Button {
                    UIPasteboard.general.url = link.searchURL
                    hapticTrigger += 1
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                UIApplication.shared.open(link.searchURL)
            } label: {
                Image(systemName: "arrow.up.right.square.fill")
                    .font(.title3)
                    .foregroundStyle(categoryColor(link.category))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
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
