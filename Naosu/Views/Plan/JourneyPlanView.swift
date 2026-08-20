import SwiftUI
import SwiftData

struct JourneyPlanView: View {
    @Binding var selectedTab: Int

    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<JourneyPlan> { $0.isCurrentWeek == true })
    private var currentPlans: [JourneyPlan]
    @Query private var allPlans: [JourneyPlan]
    @Query private var allProgress: [DayProgress]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if profiles.isEmpty {
                HealthIntakeView()
            } else if !currentPlans.isEmpty {
                TodaySessionView(selectedTab: $selectedTab)
            } else {
                HealthIntakeGeneratingView(profile: profiles.first!)
            }
        }
        .task { fixMissingProgressRecords() }
    }

    private func fixMissingProgressRecords() {
        let userId = LocalAuthManager.shared.userId
        let userPlans = allPlans.filter { $0.userId == userId }
        let existingProgress = allProgress.filter { $0.userId == userId }

        var needsSave = false

        for plan in userPlans {
            for day in plan.days {
                let exists = existingProgress.contains {
                    $0.weekNumber == plan.weekNumber &&
                    $0.dayNumber == day.dayNumber &&
                    $0.userId == userId
                }
                guard !exists else { continue }

                let totalReps = day.sections
                    .flatMap { $0.exercises }
                    .reduce(0) { $0 + ($1.sets * max($1.reps, 1)) }

                let progress = DayProgress(
                    userId: userId,
                    weekNumber: plan.weekNumber,
                    dayNumber: day.dayNumber,
                    isCompleted: day.isRestDay,
                    isRestDay: day.isRestDay,
                    completionPercentage: day.isRestDay ? 1.0 : 0.0,
                    totalPlannedReps: totalReps,
                    totalCompletedReps: 0,
                    completedExerciseIds: (try? JSONEncoder().encode([String]())) ?? Data(),
                    completedAt: day.isRestDay ? Date() : nil
                )
                modelContext.insert(progress)
                needsSave = true
            }
        }

        if needsSave {
            try? modelContext.save()
        }
    }
}

// MARK: - Generating View (auto-triggers plan generation for existing profile)

struct HealthIntakeGeneratingView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @State private var generationStep = 0
    @State private var errorMessage: String?

    private let stepLabels: [(icon: String, text: String)] = [
        ("person.text.rectangle", "Reading your profile"),
        ("brain.head.profile", "Analysing goals & limitations"),
        ("figure.strengthtraining.traditional", "Building your week"),
        ("checkmark.circle", "Plan ready")
    ]

    var body: some View {
        ZStack {
            Color.naosuBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.naosuAccent)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Building your journey")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.naosuTextPrimary)

                Text("Naosu is analysing your profile and creating a personalised plan.")
                    .font(.subheadline)
                    .foregroundStyle(.naosuTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Progress bar
                VStack(spacing: 20) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.naosuBorder)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.naosuAccent)
                                .frame(
                                    width: geo.size.width * progressFraction,
                                    height: 6
                                )
                                .animation(.easeInOut(duration: 0.5), value: generationStep)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 40)

                    // Step labels
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(stepLabels.enumerated()), id: \.offset) { index, step in
                            HStack(spacing: 12) {
                                Image(systemName: stepIcon(for: index))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(stepColor(for: index))
                                    .frame(width: 20)

                                Text(step.text)
                                    .font(.subheadline)
                                    .foregroundStyle(stepColor(for: index))
                            }
                            .animation(.easeInOut(duration: 0.3), value: generationStep)
                        }
                    }
                    .padding(.horizontal, 40)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    Button("Try again") {
                        Task { await generate() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.naosuAccent)
                }

                Spacer()
            }
        }
        .task { await generate() }
    }

    // MARK: - Helpers

    private var progressFraction: CGFloat {
        CGFloat(generationStep) / CGFloat(stepLabels.count)
    }

    private func stepIcon(for index: Int) -> String {
        if index < generationStep {
            return "checkmark.circle.fill"
        } else if index == generationStep {
            return stepLabels[index].icon
        } else {
            return stepLabels[index].icon
        }
    }

    private func stepColor(for index: Int) -> Color {
        if index < generationStep {
            return .naosuAccent
        } else if index == generationStep {
            return .naosuTextPrimary
        } else {
            return .naosuTextTertiary
        }
    }

    // MARK: - Generation

    private func generate() async {
        errorMessage = nil
        generationStep = 0

        try? await Task.sleep(for: .seconds(0.8))
        withAnimation { generationStep = 1 }
        try? await Task.sleep(for: .seconds(0.6))
        withAnimation { generationStep = 2 }

        let userId = AuthManager.shared.userId

        do {
            let response = try await APIClient.shared.generateJourney(profile: profile)
            withAnimation { generationStep = 3 }
            try? await Task.sleep(for: .seconds(0.5))

            // Persist journey structure (upsert: delete any old one first)
            let structure = JourneyStructure(
                userId: userId,
                totalWeeks: response.journeyStructure.totalWeeks,
                currentWeek: 1,
                currentDay: 1,
                phases: response.journeyStructure.phases
            )
            modelContext.insert(structure)

            // Persist Week 1 plan
            let week1 = response.week1Plan
            let plan = JourneyPlan(
                userId: userId,
                weekNumber: 1,
                phase: week1.phase,
                days: week1.days,
                isCurrentWeek: true,
                weekSummary: week1.weekSummary
            )
            modelContext.insert(plan)

            // Create DayProgress records for all 7 days
            for day in week1.days {
                let planned = day.sections.flatMap { $0.exercises }
                    .reduce(0) { $0 + ($1.sets * max($1.reps, 1)) }
                let progress = DayProgress(
                    userId: userId,
                    weekNumber: 1,
                    dayNumber: day.dayNumber,
                    isCompleted: day.isRestDay,
                    isRestDay: day.isRestDay,
                    completionPercentage: day.isRestDay ? 1.0 : 0.0,
                    totalPlannedReps: planned,
                    totalCompletedReps: 0,
                    completedExerciseIds: (try? JSONEncoder().encode([String]())) ?? Data(),
                    sessionRecordId: nil,
                    completedAt: day.isRestDay ? Date() : nil
                )
                modelContext.insert(progress)
            }

            withAnimation { generationStep = 4 }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
