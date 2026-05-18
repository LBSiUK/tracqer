import SwiftUI
import PhotosUI
import UIKit

struct AddEditRecordView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) var dismiss

    let record: VinylRecord?
    let onSaved: (VinylRecord) -> Void

    private var isEdit: Bool { record != nil }

    @State private var title            = ""
    @State private var artist           = ""
    @State private var year             = ""
    @State private var durationMinutes  = ""
    @State private var durationSeconds  = ""
    @State private var label            = ""
    @State private var format           = ""
    @State private var speed            = ""
    @State private var genre            = ""
    @State private var notes            = ""
    @State private var owner            = "me"
    @State private var discCount        = 1
    @State private var outerSleeveOnly  = false
    @State private var discCondition    = ""
    @State private var sleeveCondition  = ""

    @State private var photoDatas: [String: Data] = [:]
    @State private var isSaving        = false
    @State private var errorMsg: String? = nil

    private var durationString: String {
        if durationMinutes.isEmpty && durationSeconds.isEmpty { return "" }
        let m = durationMinutes.isEmpty ? "0" : durationMinutes
        let s = durationSeconds.isEmpty ? "00" : durationSeconds
        return "\(m):\(s)"
    }

    var body: some View {
        CompatNavigation {
            Form {
                Section("Basic Info") {
                    LabeledTextField("Artist", text: $artist, required: true,
                                     autocapitalization: .words)
                    LabeledTextField("Title",  text: $title,  required: true,
                                     autocapitalization: .words)
                    LabeledTextField("Year",   text: $year,   keyboard: .numberPad)
                    LabeledTextField("Label",  text: $label,  autocapitalization: .words)
                    LabeledTextField("Genre",  text: $genre,  autocapitalization: .words)
                    DurationField(minutes: $durationMinutes, seconds: $durationSeconds)
                }

                Section("Format & Condition") {
                    PickerRow(label: "Format",           selection: $format,          options: Formats.all)
                    PickerRow(label: "Speed (RPM)",       selection: $speed,           options: Speeds.all)
                    PickerRow(label: "Disc Condition",    selection: $discCondition,   options: Grades.all)
                    PickerRow(label: "Sleeve Condition",  selection: $sleeveCondition, options: Grades.all)
                }

                Section("Ownership") {
                    Picker("Owner", selection: $owner) {
                        ForEach(Owners.all, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Number of Discs", selection: $discCount) {
                        ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Toggle("Outer sleeve only",  isOn: $outerSleeveOnly)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .textInputAutocapitalization(.sentences)
                }

                if #available(iOS 16.0, *) {
                    Section("Sleeve Photos") {
                        let types = outerSleeveOnly
                            ? SleevePhotoType.allCases.filter { !$0.isInnerOnly }
                            : SleevePhotoType.allCases
                        ForEach(types, id: \.self) { t in
                            PhotoPickerRow(
                                label: t.label,
                                fieldName: t.rawValue,
                                existingURL: existingURL(for: t.rawValue),
                                api: appState.api!,
                                photoDatas: $photoDatas
                            )
                        }
                    }

                    ForEach(1...discCount, id: \.self) { disc in
                        Section(discCount > 1 ? "Disc \(disc) Photos" : "Disc Photos") {
                            PhotoPickerRow(label: "Side A", fieldName: "disc_front_\(disc)",
                                           existingURL: existingURL(for: "disc_front", discNumber: disc),
                                           api: appState.api!, photoDatas: $photoDatas)
                            PhotoPickerRow(label: "Side B", fieldName: "disc_back_\(disc)",
                                           existingURL: existingURL(for: "disc_back", discNumber: disc),
                                           api: appState.api!, photoDatas: $photoDatas)
                        }
                    }
                } else {
                    Section {
                        Text("Photo upload requires iOS 16 or later.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundColor(.red) }
                }
            }
            .navigationTitle(isEdit ? "Edit Record" : "Add Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? "Save" : "Add") {
                        Task { await save() }
                    }
                    .compatFontWeight(.semibold)
                    .tint(.orange)
                    .disabled(isSaving || title.isEmpty || artist.isEmpty)
                    .overlay { if isSaving { ProgressView().scaleEffect(0.8) } }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
            }
            .onAppear { prefill() }
        }
    }

    // MARK: - Helpers

    private func prefill() {
        guard let rec = record else { return }
        title           = rec.title
        artist          = rec.artist
        year            = rec.year.map(String.init) ?? ""
        label           = rec.label ?? ""
        format          = rec.format ?? ""
        speed           = rec.speed ?? ""
        genre           = rec.genre ?? ""
        notes           = rec.notes ?? ""
        owner           = rec.owner
        discCount       = rec.disc_count
        outerSleeveOnly = rec.outer_sleeve_only
        discCondition   = rec.disc_condition ?? ""
        sleeveCondition = rec.sleeve_condition ?? ""
        // Parse duration "M:SS"
        if let dur = rec.duration {
            let parts = dur.split(separator: ":")
            if parts.count == 2 {
                durationMinutes = String(parts[0])
                durationSeconds = String(parts[1])
            }
        }
    }

    private func existingURL(for photoType: String, discNumber: Int? = nil) -> URL? {
        guard let api = appState.api, let rec = record else { return nil }
        let has: Bool
        if let disc = discNumber {
            has = rec.photos.contains { $0.photo_type == photoType && $0.disc_number == disc }
        } else {
            has = rec.photos.contains { $0.photo_type == photoType && $0.disc_number == nil }
        }
        guard has else { return nil }
        return api.photoURL(recordId: rec.id, photoType: photoType, discNumber: discNumber, size: "320")
    }

    private func buildInput() -> RecordInput {
        RecordInput(
            title: title.trimmingCharacters(in: .whitespaces),
            artist: artist.trimmingCharacters(in: .whitespaces),
            year: Int(year), duration: durationString.isEmpty ? nil : durationString,
            label: label.isEmpty ? nil : label, format: format.isEmpty ? nil : format,
            speed: speed.isEmpty ? nil : speed, genre: genre.isEmpty ? nil : genre,
            notes: notes.isEmpty ? nil : notes, owner: owner,
            disc_count: discCount, outer_sleeve_only: outerSleeveOnly,
            disc_condition: discCondition.isEmpty ? nil : discCondition,
            sleeve_condition: sleeveCondition.isEmpty ? nil : sleeveCondition
        )
    }

    private func save() async {
        guard let api = appState.api else { return }

        // Year validation
        if !year.isEmpty && (year.count != 4 || Int(year) == nil) {
            errorMsg = "Year must be a 4-digit number (e.g. 1987)."
            return
        }

        isSaving = true; errorMsg = nil
        do {
            let input = buildInput()
            if !isEdit {
                let saved = try await api.createRecord(input: input, photos: photoDatas)
                onSaved(saved); dismiss()
            } else if let rec = record {
                var saved = try await api.updateRecord(rec.id, input: input)
                for (field, data) in photoDatas {
                    if field.hasPrefix("disc_front_") || field.hasPrefix("disc_back_") {
                        let parts = field.split(separator: "_")
                        if let disc = Int(parts.last ?? "") {
                            let type = parts.dropLast().joined(separator: "_")
                            try await api.uploadDiscPhoto(recordId: rec.id, photoType: type,
                                                          discNumber: disc, imageData: data)
                        }
                    } else {
                        try await api.uploadSleevePhoto(recordId: rec.id, photoType: field, imageData: data)
                    }
                }
                if outerSleeveOnly {
                    for t in ["inner_sleeve_front", "inner_sleeve_back"] {
                        if rec.photos.contains(where: { $0.photo_type == t }) {
                            try await api.deletePhoto(recordId: rec.id, photoType: t)
                        }
                    }
                }
                saved = try await api.getRecord(rec.id)
                onSaved(saved); dismiss()
            }
        } catch {
            errorMsg = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Duration field

struct DurationField: View {
    @Binding var minutes: String
    @Binding var seconds: String

    var body: some View {
        HStack {
            Text("Duration")
            Spacer()
            HStack(spacing: 2) {
                TextField("0", text: $minutes)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
                Text(":")
                    .foregroundColor(.secondary)
                TextField("00", text: $seconds)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.leading)
                    .frame(width: 32)
                    .onChange(of: seconds) { val in
                        // Clamp to 0–59
                        if let n = Int(val), n > 59 { seconds = "59" }
                    }
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: - Form helpers

struct LabeledTextField: View {
    let placeholder: String
    @Binding var text: String
    var required: Bool = false
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never

    init(_ placeholder: String, text: Binding<String>, required: Bool = false,
         keyboard: UIKeyboardType = .default,
         autocapitalization: TextInputAutocapitalization = .never) {
        self.placeholder = placeholder; self._text = text
        self.required = required; self.keyboard = keyboard
        self.autocapitalization = autocapitalization
    }

    var body: some View {
        HStack {
            Text(placeholder + (required ? " *" : ""))
            Spacer()
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(autocapitalization)
        }
    }
}

struct PickerRow: View {
    let label: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        Picker(label, selection: $selection) {
            Text("None").tag("")
            ForEach(options, id: \.self) { Text($0).tag($0) }
        }
    }
}

@available(iOS 16.0, *)
struct PhotoPickerRow: View {
    let label: String
    let fieldName: String
    let existingURL: URL?
    let api: APIClient
    @Binding var photoDatas: [String: Data]

    @State private var item: PhotosPickerItem? = nil
    @State private var localImage: UIImage?    = nil
    @State private var showingSourceDialog     = false
    @State private var showingPicker           = false
    @State private var showingCameraFlow       = false
    @State private var cameraResultImage: UIImage? = nil
    @State private var galleryCropItem: CropItem? = nil

    private var aspectRatio: CGFloat { fieldName == "sleeve_inner" ? 2.0 : 1.0 }
    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            thumbnail
        }
        .confirmationDialog("Add Photo", isPresented: $showingSourceDialog) {
            if cameraAvailable { Button("Take Photo") { showingCameraFlow = true } }
            Button("Choose from Library") { showingPicker = true }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showingPicker, selection: $item, matching: .images)
        // Camera + crop in a single fullScreenCover (no chaining)
        // Result is staged into cameraResultImage first, then applied in onDismiss
        // so state updates land after the cover has fully dismissed.
        .fullScreenCover(isPresented: $showingCameraFlow, onDismiss: {
            if let img = cameraResultImage {
                localImage = img
                photoDatas[fieldName] = img.jpegData(compressionQuality: 0.9) ?? Data()
                cameraResultImage = nil
            }
        }) {
            CameraAndCropView(aspectRatio: aspectRatio) { cropped in
                cameraResultImage = cropped
                showingCameraFlow = false
            } onCancel: {
                showingCameraFlow = false
            }
        }
        // Gallery crop — uses item-based cover so it only presents after picker fully dismisses
        .fullScreenCover(item: $galleryCropItem) { cropItem in
            CropView(image: cropItem.image, aspectRatio: cropItem.ratio) { cropped in
                localImage = cropped
                photoDatas[fieldName] = cropped.jpegData(compressionQuality: 0.9) ?? Data()
                galleryCropItem = nil
            } onCancel: {
                galleryCropItem = nil
            }
        }
        .onChange(of: item) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let img  = UIImage(data: data) {
                    // Wait for the picker sheet to fully dismiss before presenting crop
                    try? await Task.sleep(nanoseconds: 600 * 1_000_000)
                    galleryCropItem = CropItem(image: img, ratio: aspectRatio)
                }
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let img = localImage {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onTapGesture { showingSourceDialog = true }
        } else if let url = existingURL {
            APIImage(url: url, api: api)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onTapGesture { showingSourceDialog = true }
        } else {
            Button { showingSourceDialog = true } label: {
                Image(systemName: "photo.badge.plus").foregroundColor(.orange)
            }
            .buttonStyle(.borderless)
        }
    }
}
