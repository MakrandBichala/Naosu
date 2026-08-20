import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct EditInjuryView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var hasInjury = false
    @State private var selectedAreas: Set<String> = []
    @State private var description = ""

    // Document upload state
    @State private var selectedImageData: Data? = nil
    @State private var selectedPDFData: Data? = nil
    @State private var selectedFileName: String = ""
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showUploadOptions = false

    private let presetAreas = ["Knee", "Lower back", "Shoulder", "Hip", "Ankle", "Neck", "Wrist", "Elbow"]

    private var hasDocument: Bool {
        selectedImageData != nil || selectedPDFData != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.naosuBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Toggle("I have an injury or chronic pain", isOn: $hasInjury)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.naosuTextPrimary)
                            .tint(Color.naosuAccent)

                        if hasInjury {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Affected areas")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.naosuTextSecondary)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                    ForEach(presetAreas, id: \.self) { area in
                                        let selected = selectedAreas.contains(area)
                                        Button {
                                            if selected { selectedAreas.remove(area) } else { selectedAreas.insert(area) }
                                        } label: {
                                            Text(area)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(selected ? Color.naosuAccent : Color.naosuTextPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .frame(maxWidth: .infinity)
                                                .background(selected ? Color.naosuAccentLight : Color.naosuSurface)
                                                .overlay(Capsule().stroke(selected ? Color.naosuAccent : Color.naosuBorder, lineWidth: selected ? 1.5 : 1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description")
                                    .font(.caption.bold())
                                    .foregroundStyle(.naosuTextSecondary)
                                TextEditor(text: $description)
                                    .frame(height: 100)
                                    .padding(10)
                                    .background(Color.naosuSurface)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.naosuBorder, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            // Diagnosis document upload
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Diagnosis document (optional)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.naosuTextTertiary)

                                if hasDocument {
                                    uploadedCard
                                } else {
                                    emptyUploadCard
                                }
                            }
                        }

                        warningCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Injury info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.naosuTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.naosuAccent)
                }
            }
            .onAppear { loadValues() }
            .confirmationDialog("Upload diagnosis document", isPresented: $showUploadOptions, titleVisibility: .visible) {
                Button("Choose Photo") { showImagePicker = true }
                Button("Choose PDF") { showDocumentPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                PhotoPicker { pickedData, name in
                    if let pickedData = pickedData {
                        selectedImageData = pickedData
                        selectedPDFData = nil
                        selectedFileName = name.isEmpty ? "photo.jpg" : name
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { data, name in
                    selectedPDFData = data
                    selectedImageData = nil
                    selectedFileName = name
                }
            }
        }
    }

    // MARK: - Upload cards

    private var emptyUploadCard: some View {
        Button {
            showUploadOptions = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.naosuAccent)
                Text("Tap to upload")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.naosuAccent)
                Text("Photo or PDF")
                    .font(.system(size: 11))
                    .foregroundStyle(.naosuTextTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.naosuAccentLight)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.naosuAccent, style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var uploadedCard: some View {
        VStack(spacing: 0) {
            // Preview
            if let img = selectedImageData, let uiImage = UIImage(data: img) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .clipped()
            } else if let pdf = selectedPDFData {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.naosuAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedFileName.isEmpty ? "Document.pdf" : selectedFileName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.naosuTextPrimary)
                            .lineLimit(1)
                        Text(formatBytes(pdf.count))
                            .font(.system(size: 11))
                            .foregroundStyle(.naosuTextTertiary)
                    }
                    Spacer()
                }
                .padding(14)
            }

            // Actions
            HStack {
                Button {
                    showUploadOptions = true
                } label: {
                    Text("Replace")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.naosuAccent)
                }
                Spacer()
                Button {
                    selectedImageData = nil
                    selectedPDFData = nil
                    selectedFileName = ""
                } label: {
                    Text("Remove")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.naosuSurface)
        }
        .background(Color.naosuSurface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.naosuBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Load / Save

    private func loadValues() {
        guard let p = profiles.first else { return }
        hasInjury = p.hasInjury
        selectedAreas = Set(p.injuredAreas)
        description = p.injuryDescription

        if let existing = p.injuryDocumentData {
            if InjuryDocumentType.isPDF(existing) {
                selectedPDFData = existing
                selectedImageData = nil
                selectedFileName = "Document.pdf"
            } else {
                selectedImageData = existing
                selectedPDFData = nil
                selectedFileName = "photo.jpg"
            }
        }
    }

    private func save() {
        guard let p = profiles.first else { dismiss(); return }
        p.hasInjury = hasInjury
        p.injuredAreas = Array(selectedAreas)
        p.injuryDescription = description

        if let img = selectedImageData {
            p.injuryDocumentData = img
        } else if let pdf = selectedPDFData {
            p.injuryDocumentData = pdf
        } else {
            p.injuryDocumentData = nil
        }

        dismiss()
    }

    private func formatBytes(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(count))
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.naosuAccent)
            Text("Editing your profile may trigger a new AI journey plan to be generated based on your updated info.")
                .font(.system(size: 13))
                .foregroundStyle(.naosuTextSecondary)
        }
        .padding(14)
        .background(Color.naosuAccentLight)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.naosuAccent.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Document type detection

enum InjuryDocumentType {
    /// PDF files start with the magic bytes "%PDF"
    static func isPDF(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let magic = [UInt8](data.prefix(4))
        return magic == [0x25, 0x50, 0x44, 0x46]
    }
}

// MARK: - PhotoPicker (PHPickerViewController wrapper)

struct PhotoPicker: UIViewControllerRepresentable {
    var onPick: (Data?, String) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Data?, String) -> Void
        init(onPick: @escaping (Data?, String) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }
            let provider = result.itemProvider
            let suggestedName = provider.suggestedName ?? "photo"

            // Prefer UIImage load for broad format support, then re-encode as JPEG
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [onPick] object, _ in
                    let image = object as? UIImage
                    let data = image?.jpegData(compressionQuality: 0.85)
                    DispatchQueue.main.async {
                        onPick(data, "\(suggestedName).jpg")
                    }
                }
            } else {
                DispatchQueue.main.async { self.onPick(nil, "") }
            }
        }
    }
}

// DocumentPicker is defined in HealthIntakeView.swift — no redeclaration needed here.
