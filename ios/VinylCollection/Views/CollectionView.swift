import SwiftUI

// MARK: - Root collection screen

struct CollectionView: View {
    @EnvironmentObject private var appState: AppState

    @State private var search           = ""
    @State private var isSearchPresented = false
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabView
            } else {
                classicTabView
            }
        }
        .tint(.orange)
        .task {
            if appState.records.isEmpty {
                await appState.loadRecords()
            }
        }
    }

    // iOS 18+ Tab DSL — Liquid Glass on iOS 26 thanks to role: .search
    @available(iOS 18.0, *)
    private var modernTabView: some View {
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
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                searchTabContent
            }
        }
    }

    // Classic TabView + .tabItem fallback for iOS 15-17
    private var classicTabView: some View {
        TabView {
            RecordListView(typeFilter: .all)
                .tabItem { Label("All", systemImage: "music.note.list") }
            RecordListView(typeFilter: .lp)
                .tabItem { Label("LPs", systemImage: "opticaldisc") }
            RecordListView(typeFilter: .singles)
                .tabItem { Label("Singles", systemImage: "music.note") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
            searchTabContent
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
    }

    // Search tab body shared by both styles. .searchable(isPresented:) is iOS 17+,
    // so iOS 15-16 falls back to the basic .searchable(text:prompt:) without programmatic focus.
    private var searchTabContent: some View {
        CompatNavigation {
            Group {
                if #available(iOS 17.0, *) {
                    searchContent
                        .searchable(text: $search,
                                    isPresented: $isSearchPresented,
                                    prompt: "Search records, artists…")
                        .onAppear { isSearchPresented = true }
                } else {
                    searchContent
                        .searchable(text: $search, prompt: "Search records, artists…")
                }
            }
            .navigationTitle("Search")
            .onChange(of: search) { newValue in
                searchTask?.cancel()
                guard !newValue.isEmpty else {
                    appState.searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 350 * 1_000_000)
                    guard !Task.isCancelled else { return }
                    await appState.performSearch(query: newValue)
                }
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if search.isEmpty {
            CompatContentUnavailable(
                "Search",
                systemImage: "magnifyingglass",
                description: Text("Search by artist, title, label, or genre.")
            )
        } else if appState.searchResults.isEmpty {
            CompatSearchUnavailable(searchText: search)
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
    @EnvironmentObject private var appState: AppState
    let typeFilter: RecordTypeFilter

    @State private var showingAdd = false

    private var records: [VinylRecord] {
        appState.records.filter { typeFilter.matches($0) }
    }

    var body: some View {
        CompatNavigation {
            Group {
                if appState.isLoading && appState.records.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if records.isEmpty {
                    CompatContentUnavailable(
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
                ToolbarItem(placement: .navigationBarTrailing) {
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
    @EnvironmentObject private var appState: AppState

    var body: some View {
        CompatNavigation {
            List {
                Section {
                    Button("Log Out", role: .destructive) {
                        appState.logout()
                    }
                }

                Section {
                    VStack(spacing: 6) {
                        Text("Tracqer v\(Bundle.main.shortVersionString) (\(Bundle.main.buildDateString))")
                            .font(.caption2)
                            .foregroundColor(Color(.tertiaryLabel))
                            .multilineTextAlignment(.center)
                        Text("Made with ❤️ in London and Brighton")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Text("by Leon Brahams")
                            .font(.footnote)
                            .foregroundColor(.secondary)
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
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray6))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(record.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
