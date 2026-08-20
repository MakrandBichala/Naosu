import SwiftUI
import SwiftData

struct EditGoalView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var goal = ""
    @State private var fitnessLevel = ""
    @State private var trainingLocation = ""
    @State private var daysPerWeek = 4

    private let goals = ["Recover from injury", "Build muscle", "Lose weight", "General fitness"]
    private let levels = ["Beginner", "Intermediate", "Advanced"]
    private let locations = ["Gym", "Home", "Outdoors"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.naosuBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        sectionLabel("Goal")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(goals, id: \.self) { g in
                                selectableCard(title: g, selected: goal == g) { goal = g }
                            }
                        }

                        sectionLabel("Fitness level")
                        Picker("Level", selection: $fitnessLevel) {
                            ForEach(levels, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        sectionLabel("Training location")
                        HStack(spacing: 10) {
                            ForEach(locations, id: \.self) { loc in
                                selectableCard(title: loc, selected: trainingLocation == loc) { trainingLocation = loc }
                            }
                        }

                        sectionLabel("Days per week")
                        HStack(spacing: 10) {
                            ForEach(2...6, id: \.self) { d in
                                Button { daysPerWeek = d } label: {
                                    Text("\(d)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 48, height: 48)
                                        .background(daysPerWeek == d ? Color.naosuAccent : Color.naosuSurface)
                                        .foregroundStyle(daysPerWeek == d ? Color.white : Color.naosuTextPrimary)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(daysPerWeek == d ? Color.clear : Color.naosuBorder, lineWidth: 1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        warningCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Goal & fitness")
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
        goal = p.goal
        fitnessLevel = p.fitnessLevel
        trainingLocation = p.trainingLocation
        daysPerWeek = p.daysPerWeek > 0 ? p.daysPerWeek : 4
    }

    private func save() {
        guard let p = profiles.first else { dismiss(); return }
        if !goal.isEmpty { p.goal = goal }
        if !fitnessLevel.isEmpty { p.fitnessLevel = fitnessLevel }
        if !trainingLocation.isEmpty { p.trainingLocation = trainingLocation }
        p.daysPerWeek = daysPerWeek
        dismiss()
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.naosuTextSecondary)
    }

    private func selectableCard(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(selected ? Color.naosuAccent : Color.naosuTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.naosuAccentLight : Color.naosuSurface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.naosuAccent : Color.naosuBorder, lineWidth: selected ? 1.5 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
