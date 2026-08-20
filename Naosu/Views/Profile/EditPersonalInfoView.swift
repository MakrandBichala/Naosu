import SwiftUI
import SwiftData

struct EditPersonalInfoView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var age = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var sex = ""
    private let sexOptions = ["Male", "Female", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.naosuBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            inputField(label: "Full name", placeholder: "Your name", text: $name, keyboard: .default)
                            inputField(label: "Age", placeholder: "e.g. 25", text: $age, keyboard: .numberPad)
                            inputField(label: "Weight (kg)", placeholder: "e.g. 70", text: $weight, keyboard: .decimalPad)
                            inputField(label: "Height (cm)", placeholder: "e.g. 175", text: $height, keyboard: .numberPad)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Biological sex")
                                    .font(.caption.bold())
                                    .foregroundStyle(.naosuTextSecondary)
                                Picker("Sex", selection: $sex) {
                                    ForEach(sexOptions, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        warningCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Personal info")
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
        }
    }

    private func loadValues() {
        guard let p = profiles.first else { return }
        name = p.name
        age = p.age > 0 ? "\(p.age)" : ""
        weight = p.weight > 0 ? String(format: "%.0f", p.weight) : ""
        height = p.height > 0 ? String(format: "%.0f", p.height) : ""
        sex = p.sex
    }

    private func save() {
        guard let p = profiles.first else { dismiss(); return }
        if !name.isEmpty { p.name = name }
        if let a = Int(age), a > 0 { p.age = a }
        if let w = Double(weight), w > 0 { p.weight = w }
        if let h = Double(height), h > 0 { p.height = h }
        if !sex.isEmpty { p.sex = sex }
        if !name.isEmpty { LocalAuthManager.shared.userName = name }
        dismiss()
    }

    @ViewBuilder
    private func inputField(label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.naosuTextSecondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.naosuSurface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.naosuBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
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
