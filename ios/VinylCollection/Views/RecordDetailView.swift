import SwiftUI

struct RecordDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) var dismiss

    let record: VinylRecord

    @State private var current: VinylRecord
    @State private var showingEdit   = false
    @State private var showingDelete = false
    @State private var isDeleting    = false
    @State private var error: String? = nil

    init(record: VinylRecord) {
        self.record = record
        _current    = State(initialValue: record)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                if !current.photos.isEmpty {
                    PhotoSectionView(record: current, api: appState.api!)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(current.artist)
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(current.title)
                        .font(.title.bold())
                    if let year = current.year {
                        Text(String(year))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if let fmt = current.format { Chip(fmt, .orange) }
                            if let spd = current.speed  { Chip("\(spd) RPM", .gray) }
                            Chip(current.owner, .blue)
                        }
                        .padding(.horizontal, 1)
                    }
                }
                .padding(.horizontal)

                Divider()

                metadataSection

                if let err = error {
                    Text(err).foregroundStyle(.red).padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit") { showingEdit = true }
                    Button("Delete", role: .destructive) { showingDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddEditRecordView(record: current) { updated in
                current = updated
            }
        }
        .confirmationDialog(
            "Delete \"\(current.title)\"?",
            isPresented: $showingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteRecord() }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetaRow("Label",            current.label)
            MetaRow("Genre",            current.genre)
            MetaRow("Duration",         current.duration)
            MetaRow("Discs",            String(current.disc_count))
            MetaRow("Disc Condition",   current.disc_condition)
            MetaRow("Sleeve Condition", current.sleeve_condition)
            if current.outer_sleeve_only {
                MetaRow("Sleeve", "Outer only")
            }
            if let notes = current.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(notes)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                Divider()
            }
        }
    }

    private func deleteRecord() async {
        isDeleting = true
        do {
            try await appState.deleteRecord(current.id)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - Photo section

struct PhotoSectionView: View {
    let record: VinylRecord
    let api: APIClient

    private let outerSleeveTypes = ["sleeve_front", "sleeve_back", "sleeve_inner"]
    private let innerSleeveTypes = ["inner_sleeve_front", "inner_sleeve_back"]

    private var outerSleevePhotos: [Photo] {
        record.photos.filter { outerSleeveTypes.contains($0.photo_type) }
    }
    private var innerSleevePhotos: [Photo] {
        record.photos.filter { innerSleeveTypes.contains($0.photo_type) }
    }
    private var discPhotos: [Photo] {
        record.photos.filter { ["disc_front", "disc_back"].contains($0.photo_type) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !outerSleevePhotos.isEmpty {
                sectionLabel("Outer Sleeve")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(outerSleevePhotos) { photo in
                            PhotoThumb(photo: photo, record: record, api: api)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            if !innerSleevePhotos.isEmpty {
                sectionLabel("Inner Sleeve")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(innerSleevePhotos) { photo in
                            PhotoThumb(photo: photo, record: record, api: api)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            let discNums = Array(Set(discPhotos.compactMap { $0.disc_number })).sorted()
            ForEach(discNums, id: \.self) { disc in
                let photos = discPhotos.filter { $0.disc_number == disc }
                sectionLabel(discNums.count > 1 ? "Disc \(disc)" : "Disc")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            PhotoThumb(photo: photo, record: record, api: api)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 8)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal)
    }
}

struct PhotoThumb: View {
    let photo: Photo
    let record: VinylRecord
    let api: APIClient

    @State private var showFull = false
    private var isGatefold: Bool { photo.photo_type == "sleeve_inner" }

    var body: some View {
        APIImage(
            url: api.photoURL(recordId: record.id, photoType: photo.photo_type,
                              discNumber: photo.disc_number, size: "320"),
            api: api
        )
        .frame(width: isGatefold ? 240 : 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { showFull = true }
        .fullScreenCover(isPresented: $showFull) {
            FullPhotoView(
                url: api.photoURL(recordId: record.id, photoType: photo.photo_type,
                                  discNumber: photo.disc_number, size: "original"),
                api: api
            )
        }
    }
}

struct FullPhotoView: View {
    let url: URL
    let api: APIClient
    @Environment(\.dismiss) var dismiss

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            APIImage(url: url, api: api)
                .scaledToFit()
                .scaleEffect(scale * pinchScale)
                .offset(x: offset.width + dragOffset.width,
                        y: offset.height + dragOffset.height)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .updating($pinchScale) { value, state, _ in state = value }
                            .onEnded { value in
                                scale = max(1, scale * value)
                                if scale <= 1 { offset = .zero }
                            },
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                guard scale > 1 else { return }
                                state = value.translation
                            }
                            .onEnded { value in
                                guard scale > 1 else { return }
                                offset.width  += value.translation.width
                                offset.height += value.translation.height
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        if scale > 1 { scale = 1; offset = .zero }
                        else         { scale = 2 }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .padding()
            }
        }
    }
}

// MARK: - Reusable components

struct MetaRow: View {
    let label: String
    let value: String?

    init(_ label: String, _ value: String?) {
        self.label = label; self.value = value
    }

    var body: some View {
        if let v = value, !v.isEmpty {
            HStack {
                Text(label)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(width: 140, alignment: .leading)
                Text(v).font(.subheadline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
        }
    }
}

struct Chip: View {
    let text: String
    let color: Color
    init(_ text: String, _ color: Color) { self.text = text; self.color = color }

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
