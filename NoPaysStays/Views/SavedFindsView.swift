import SwiftUI

struct SavedFindsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showAddSheet: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.savedFinds.isEmpty {
                    ContentUnavailableView(
                        "No Saved Finds",
                        systemImage: "bookmark.slash",
                        description: Text("Save interesting links from search results to collect them here")
                    )
                } else {
                    List {
                        ForEach(Array(viewModel.savedFinds.enumerated()), id: \.element.id) { index, find in
                            SavedFindRow(find: find)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 15)
                                .animation(.spring(response: 0.4).delay(Double(index) * 0.05), value: appeared)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel.deleteSavedFind(viewModel.savedFinds[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                    .onAppear { appeared = true }
                }
            }
            .navigationTitle("Saved Finds")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddSavedFindView()
            }
        }
    }
}

struct SavedFindRow: View {
    let find: SavedFind

    var body: some View {
        Button {
            if let url = URL(string: find.url) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                VStack {
                    Image(systemName: platformIcon(find.platform))
                        .font(.title3)
                        .foregroundStyle(AppTheme.burntOrange)
                }
                .frame(width: 40, height: 40)
                .background(AppTheme.burntOrange.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(find.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(find.platform)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let price = find.pricePerNight {
                        Text("$\(price)/night")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.savingsGreen)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func platformIcon(_ platform: String) -> String {
        let lower = platform.lowercased()
        if lower.contains("google") || lower.contains("bing") || lower.contains("duck") { return "magnifyingglass" }
        if lower.contains("gumtree") || lower.contains("facebook") { return "newspaper.fill" }
        if lower.contains("reddit") || lower.contains("whirlpool") { return "bubble.left.fill" }
        if lower.contains("visit") || lower.contains("tourism") || lower.contains("council") { return "map.fill" }
        if lower.contains("owner") { return "person.fill.checkmark" }
        return "house.fill"
    }
}

struct AddSavedFindView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var platform: String = ""
    @State private var url: String = ""
    @State private var notes: String = ""
    @State private var priceStr: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title (e.g. Beach House Byron Bay)", text: $title)
                    TextField("Platform (e.g. Stayz, Owner Direct)", text: $platform)
                    TextField("URL", text: $url)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Optional") {
                    TextField("Price per night ($)", text: $priceStr)
                        .keyboardType(.numberPad)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Find")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let find = SavedFind(
                            title: title,
                            platform: platform,
                            url: url,
                            notes: notes,
                            pricePerNight: Int(priceStr)
                        )
                        viewModel.addSavedFind(find)
                        dismiss()
                    }
                    .disabled(title.isEmpty || url.isEmpty)
                }
            }
        }
    }
}
