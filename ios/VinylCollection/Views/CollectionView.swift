import SwiftUI

// MARK: - Root collection screen

struct CollectionView: View {
    @Environment(AppState.self) private var appState

    @State private var search           = ""
    @State private var isSearchPresented = false
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        TabView {
            Tab("All", systemImage: "music.note.list") {
                RecordListView(typeFilter: .all)
            }
            Tab("LPs", systemImage: "opticaldisc") {
                RecordListView(typeFilter: .lp)
            }
            Tab("Singles", systemImage: "music.note") {
                RecordListView(typeFilter: .singles)
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
            // role: .search → iOS 26 floats this as a separate Liquid Glass circle
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack {
                    searchContent
                        .navigationTitle("Search")
                        .searchable(text: $search,
                                    isPresented: $isSearchPresented,
                                    prompt: "Search records, artists…")
                        .onChange(of: search) { _, newValue in
                            searchTask?.cancel()
                            guard !newValue.isEmpty else {
                                appState.searchResults = []
                                return
                            }
                            searchTask = Task {
                                try? await Task.sleep(for: .milliseconds(350))
                                guard !Task.isCancelled else { return }
                                await appState.performSearch(query: newValue)
                            }
                        }
                        // Auto-show keyboard when search tab is opened
                        .onAppear { isSearchPresented = true }
                }
            }
        }
        .tint(.orange)
        .task {
            if appState.records.isEmpty {
                await appState.loadRecords()
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if search.isEmpty {
            ContentUnavailableView(
                "Search",
                systemImage: "magnifyingglass",
                description: Text("Search by artist, title, label, or genre.")
            )
        } else if appState.searchResults.isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            List {
                ForEach(appState.searchResults) { record in
                    if let api = appState.api {
                        NavigationLink(destination: RecordDetailView(record: record)) {
                            RecordRow(record: record, api: api)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Per-filter list tab

struct RecordListView: View {
    @Environment(AppState.self) private var appState
    let typeFilter: RecordTypeFilter

    @State private var showingAdd = false

    private var records: [VinylRecord] {
        appState.records.filter { typeFilter.matches($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.isLoading && appState.records.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if records.isEmpty {
                    ContentUnavailableView(
                        "No Records",
                        systemImage: "record.circle",
                        description: Text(
                            typeFilter == .all
                                ? "Add your first record."
                                : "No \(typeFilter.rawValue.lowercased()) in your collection."
                        )
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            if let api = appState.api {
                                NavigationLink(destination: RecordDetailView(record: record)) {
                                    RecordRow(record: record, api: api)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(typeFilter == .all ? "Tracqer" : typeFilter.rawValue)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await appState.loadRecords()
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddEditRecordView(record: nil) { _ in
                Task { await appState.loadRecords() }
            }
        }
    }
}

// MARK: - Settings tab

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Log Out", role: .destructive) {
                        appState.logout()
                    }
                }

                Section {
                    VStack(spacing: 6) {
                        Text("Made with ❤️ in London and Brighton")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("by Leon Brahams")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("v1.0")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Row

struct RecordRow: View {
    let record: VinylRecord
    let api: APIClient

    private var coverPhoto: Photo? {
        record.photos.first { $0.photo_type == "sleeve_front" } ?? record.photos.first
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let photo = coverPhoto {
                    APIImage(
                        url: api.photoURL(recordId: record.id, photoType: photo.photo_type,
                                          discNumber: photo.disc_number, size: "240"),
                        api: api
                    )
                } else {
                    Image(systemName: "record.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray6))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(record.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(record.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let fmt = record.format { Chip(fmt, .orange) }
                    Chip(record.owner, .blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
