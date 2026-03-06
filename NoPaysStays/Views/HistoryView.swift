import SwiftUI

struct HistoryView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.searchHistory.isEmpty {
                    ContentUnavailableView(
                        "No Search History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Your deep searches will appear here")
                    )
                } else {
                    List {
                        ForEach(Array(viewModel.searchHistory.enumerated()), id: \.element.id) { index, criteria in
                            HistoryRow(criteria: criteria) {
                                viewModel.rerunSearch(criteria)
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(.spring(response: 0.4).delay(Double(index) * 0.04), value: appeared)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel.deleteHistoryItem(viewModel.searchHistory[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                    .onAppear { appeared = true }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !viewModel.searchHistory.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear All", role: .destructive) {
                            viewModel.clearHistory()
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }
}

struct HistoryRow: View {
    let criteria: SearchCriteria
    let onRerun: () -> Void
    @State private var showResults: Bool = false
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        Button {
            viewModel.rerunSearch(criteria)
            showResults = true
        } label: {
            HStack(spacing: 12) {
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.coral)
                }
                .frame(width: 36, height: 36)
                .background(AppTheme.coral.opacity(0.1))
                .clipShape(.rect(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text(criteria.location)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(criteria.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(criteria.dateRangeText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(criteria.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.burntOrange)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showResults) {
            SearchResultsView()
        }
    }
}
