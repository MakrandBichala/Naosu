import SwiftUI
import SwiftData

struct TodaySessionView: View {
    @Binding var selectedTab: Int

    // MARK: - Queries
    @Query private var plans: [JourneyPlan]
    @Query private var allProgress: [DayProgress]
    @Query private var allIncomplete: [IncompleteSession]
    @Query private var journeyStructures: [JourneyStructure]
    @Query private var profiles: [UserProfile]
    @Query private var sessionRecords: [SessionRecord]
    @Environment(\.modelContext) private var modelContext

    // MARK: - Local state
    @State private var tookRestDay = false
    @State private var showWeekComplete = false
    @State private var completedWeekNumber = 0
    @State private var selectedExercise: JourneyExercise? = nil
    @State private var selectedSectionTitle: String = ""
    @State private var isGeneratingNextWeek = false

    // MARK: - Derived

    private var userId: String { AuthManager.shared.userId }

    /// The first incomplete day, resolved in progress order (not calendar order).
    private var currentResult: (plan: JourneyPlan, day: DaySession)? {
        JourneyManager.shared.getCurrentDay(
            plans: plans,
            progress: allProgress,
            userId: userId
        )
    }

    /// DayProgress record matching the current day.
    private var currentDayProgress: DayProgress? {
        guard let r = currentResult else { return nil }
        return allProgress.first {
            $0.userId == userId &&
            $0.weekNumber == r.plan.weekNumber &&
            $0.dayNumber == r.day.dayNumber
        }
    }

    /// Exercise IDs already finished in a previous partial session.
    private var completedExerciseIds: [String] {
        guard let dp = currentDayProgress else { return [] }
        return JourneyManager.shared.getCompletedExerciseIds(dayProgress: dp)
    }

    /// True when the user has started but not yet finished today's session.
    private var isSessionIncomplete: Bool {
        guard let dp = currentDayProgress else { return false }
        return !dp.isCompleted &&
               dp.totalCompletedReps > 0 &&
               dp.completionPercentage < 0.8
    }

    /// Total exercises in today's day (for live completion fraction display).
    private var totalExercisesInDay: Int {
        currentResult?.day.sections.flatMap { $0.exercises }.count ?? 0
    }

    /// Live fraction of exercises done (0.0 – 1.0).
    private var liveFraction: Double {
        guard let dp = currentDayProgress, totalExercisesInDay > 0 else { return 0 }
        return JourneyManager.shared.liveFraction(
            dayProgress: dp, totalExercises: totalExercisesInDay)
    }

    private var incompleteForToday: IncompleteSession? {
        allIncomplete.first { $0.userId == userId }
    }

    /// Next incomplete day after the current one (for the rest-day preview).
    private var nextDay: DaySession? {
        guard let r = currentResult else { return nil }
        return JourneyManager.shared.getNextDay(
            after: r.day.dayNumber,
            inWeek: r.plan.weekNumber,
            plans: plans,
            progress: allProgress,
            userId: userId
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.naosuBackground.ignoresSafeArea()

            if let result = currentResult {
                if result.day.isRestDay || tookRestDay {
                    restDayView(day: result.day)
                } else {
                    activeSessionView(plan: result.plan, session: result.day)
                }
            } else {
                nilResultView
            }
        }
        .task { checkWeekCompletion() }
        .onChange(of: allProgress) { _, _ in
            checkWeekCompletion()
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailView(
                exercise: exercise,
                sectionTitle: selectedSectionTitle
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showWeekComplete) {
            WeekCompleteView(
                weekNumber: completedWeekNumber,
                allProgress: allProgress,
                journeyStructure: journeyStructures.first(where: { $0.userId == userId }),
                onContinue: { showWeekComplete = false }
            )
        }
    }

    // MARK: - Week Completion Check

    private func checkWeekCompletion() {
        guard !showWeekComplete else { return }

        // Find the most recently completed non-rest day
        let recentlyCompleted = allProgress
            .filter { $0.userId == userId && $0.isCompleted && !$0.isRestDay && $0.completedAt != nil }
            .max(by: { $0.completedAt! < $1.completedAt! })

        guard let lastCompleted = recentlyCompleted else { return }
        let weekNum = lastCompleted.weekNumber

        // Skip if next week's plan already exists (already processed)
        guard !plans.contains(where: { $0.weekNumber == weekNum + 1 && $0.userId == userId }) else { return }

        let weekDone = JourneyManager.shared.isWeekComplete(
            weekNumber: weekNum,
            progress: allProgress,
            userId: userId
        )

        if weekDone {
            completedWeekNumber = weekNum
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showWeekComplete = true
            }
        }
    }

    // MARK: - Actions

    private func switchToSessionsTab() {
        guard let day = currentResult?.day else { return }
        let remaining = day.sections
            .flatMap { $0.exercises }
            .filter { !completedExerciseIds.contains($0.id) }
        NavigationState.shared.triggerRecording(exercises: remaining)
        selectedTab = 1
    }

    private func takeRestDay() {
        withAnimation(.easeInOut(duration: 0.3)) { tookRestDay = true }
    }

    private func undoRestDay() {
        withAnimation(.easeInOut(duration: 0.3)) { tookRestDay = false }
    }

    // MARK: - Active Session View

    @ViewBuilder
    private func activeSessionView(plan: JourneyPlan, session: DaySession) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date + title
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedDate)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.naosuTextTertiary)

                        Text("Today's session")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.naosuTextPrimary)
                    }

                    // Incomplete-session banner
                    if isSessionIncomplete {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.naosuAccent)
                            Text("Pick up where you left off")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.naosuAccent)
                            Spacer()
                            Text("\(Int(liveFraction * 100))% done")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.naosuAccent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.naosuAccent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.naosuAccent, lineWidth: 1)
                        )
                    }

                    // Phase + day info card
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.phase.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.naosuAccent)
                                .tracking(0.5)
                            Text(session.sessionTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.naosuTextPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Week \(plan.weekNumber)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.naosuTextTertiary)
                            Text("Day \(session.dayNumber)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.naosuAccent)
                        }
                    }
                    .padding(12)
                    .background(Color.naosuSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.naosuBorder, lineWidth: 1)
                    )

                    // Section cards (with fallback for empty sections)
                    if session.sections.isEmpty || session.sections.allSatisfy({ $0.exercises.isEmpty }) {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.naosuTextTertiary)
                            Text("Exercise data unavailable")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.naosuTextSecondary)
                            Text("Try generating your next week again.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.naosuTextTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.naosuSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.naosuBorder, lineWidth: 1))
                    } else {
                        ForEach(session.sections) { section in
                            sectionCard(section: section)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 180)
            }

            // Floating action bar
            VStack(spacing: 8) {
                Button(action: switchToSessionsTab) {
                    Text(startButtonLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.naosuAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: takeRestDay) {
                    Text("Take a rest day")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.naosuTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// Adaptive label for the primary action button.
    private var startButtonLabel: String {
        if isSessionIncomplete { return "Resume session" }
        return "Start session"
    }

    // MARK: - Section Card

    @ViewBuilder
    private func sectionCard(section: SessionSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with completion counter
            let doneCount = section.exercises
                .filter { completedExerciseIds.contains($0.id) }.count
            let totalCount = section.exercises.count
            let allDone = doneCount == totalCount

            HStack {
                Text(section.title.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.naosuTextTertiary)
                    .tracking(0.5)
                Spacer()
                if allDone {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.naosuAccent)
                        Text("Done")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.naosuAccent)
                    }
                } else if doneCount > 0 {
                    Text("\(doneCount)/\(totalCount)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.naosuTextTertiary)
                }
            }
            .padding(.bottom, 8)

            // Exercise rows
            VStack(spacing: 0) {
                ForEach(Array(section.exercises.enumerated()), id: \.element.id) { index, exercise in
                    Button {
                        selectedSectionTitle = section.title
                        selectedExercise = exercise
                    } label: {
                        exerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)

                    if index < section.exercises.count - 1 {
                        Divider()
                            .background(Color.naosuBorder)
                            .padding(.vertical, 10)
                    }
                }
            }
            .padding(16)
            .background(Color.naosuSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.naosuBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Exercise Row

    @ViewBuilder
    private func exerciseRow(exercise: JourneyExercise) -> some View {
        let isDone = completedExerciseIds.contains(exercise.id)

        HStack(alignment: .center, spacing: 10) {
            // Completion indicator circle
            ZStack {
                Circle()
                    .fill(isDone ? Color.naosuAccent : Color.naosuAccent.opacity(0.12))
                    .frame(width: 22, height: 22)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            // Name + notes
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isDone ? Color.naosuTextTertiary : Color.naosuTextPrimary)
                    .strikethrough(isDone)

                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.caption)
                        .foregroundStyle(Color.naosuTextTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Sets × reps / duration
            Text(exerciseLabel(exercise))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(isDone ? Color.naosuTextTertiary : Color.naosuAccent)
        }
        .opacity(isDone ? 0.6 : 1.0)
    }

    // MARK: - Rest Day View

    @ViewBuilder
    private func restDayView(day: DaySession) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.naosuAccent)

                Text("Rest day")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.naosuTextPrimary)

                Text("Your body recovers and grows stronger during rest. Take it easy today.")
                    .font(.subheadline)
                    .foregroundStyle(Color.naosuTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                nextDayPreview

                Spacer()
            }

            // Cancel button only when user voluntarily chose rest (not a scheduled rest day)
            if tookRestDay && !day.isRestDay {
                Button(action: undoRestDay) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.naosuAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var nextDayPreview: some View {
        if let next = nextDay, !next.isRestDay {
            VStack(alignment: .leading, spacing: 8) {
                Text("NEXT SESSION PREVIEW")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.naosuTextTertiary)
                    .tracking(0.5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(next.sessionTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.naosuTextPrimary)

                    let sections = next.sections.count
                    let exercises = next.sections.reduce(0) { $0 + $1.exercises.count }
                    Text("\(sections) sections \u{00B7} \(exercises) exercises")
                        .font(.caption)
                        .foregroundStyle(Color.naosuTextSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.naosuSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.naosuBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    // MARK: - Nil Result View (smart fallback when getCurrentDay returns nil)

    @ViewBuilder
    private var nilResultView: some View {
        let userProgress = allProgress.filter { $0.userId == userId }
        let userPlans = plans.filter { $0.userId == userId }

        if userPlans.isEmpty {
            noSessionView(
                icon: "exclamationmark.circle",
                title: "No plan found",
                message: "Something went wrong. Please restart the app.",
                buttonTitle: nil,
                buttonAction: nil
            )
        } else if userProgress.isEmpty {
            noSessionView(
                icon: "exclamationmark.circle",
                title: "Setting up your days",
                message: "Tap to fix your progress tracking.",
                buttonTitle: "Fix now",
                buttonAction: { fixMissingProgress() }
            )
        } else if userProgress.allSatisfy({ $0.isCompleted }) {
            noSessionView(
                icon: "checkmark.circle.fill",
                title: "Week complete!",
                message: "All sessions done. Your next week will be generated soon.",
                buttonTitle: isGeneratingNextWeek ? "Generating..." : "Generate next week",
                buttonAction: isGeneratingNextWeek ? nil : { generateNextWeekManually() }
            )
        } else {
            noSessionView(
                icon: "arrow.clockwise",
                title: "Loading your session",
                message: "Pull down to refresh",
                buttonTitle: "Refresh",
                buttonAction: { Task { @MainActor in
                    // Force SwiftData to re-evaluate by triggering a no-op state change
                    tookRestDay = tookRestDay
                }}
            )
        }
    }

    // MARK: - No Session View Helper

    @ViewBuilder
    private func noSessionView(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String?,
        buttonAction: (() -> Void)?
    ) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.naosuAccent)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.naosuTextPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.naosuTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.naosuAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    // MARK: - Fix Missing Progress

    private func fixMissingProgress() {
        let userPlans = plans.filter { $0.userId == userId }
        let existingProgress = allProgress.filter { $0.userId == userId }

        for plan in userPlans {
            for day in plan.days {
                let exists = existingProgress.contains {
                    $0.weekNumber == plan.weekNumber &&
                    $0.dayNumber == day.dayNumber
                }
                guard !exists else { continue }

                let totalReps = day.sections
                    .flatMap { $0.exercises }
                    .reduce(0) { $0 + ($1.sets * $1.reps) }
                let emptyIds = (try? JSONEncoder().encode([String]())) ?? Data()

                let progress = DayProgress(
                    userId: userId,
                    weekNumber: plan.weekNumber,
                    dayNumber: day.dayNumber,
                    isCompleted: day.isRestDay,
                    isRestDay: day.isRestDay,
                    completionPercentage: day.isRestDay ? 1.0 : 0.0,
                    totalPlannedReps: totalReps,
                    totalCompletedReps: 0,
                    completedExerciseIds: emptyIds,
                    completedAt: day.isRestDay ? Date() : nil
                )
                modelContext.insert(progress)
            }
        }
        try? modelContext.save()
    }

    // MARK: - Generate Next Week Manually

    private func generateNextWeekManually() {
        guard !isGeneratingNextWeek else { return }
        isGeneratingNextWeek = true

        Task {
            do {
                guard let structure = journeyStructures.first(where: { $0.userId == userId }) else {
                    isGeneratingNextWeek = false
                    return
                }

                let currentWeek = plans
                    .filter { $0.userId == userId }
                    .map { $0.weekNumber }
                    .max() ?? 1

                let profile = profiles.first { $0.userId == userId }

                _ = try await JourneyManager.shared.generateNextWeek(
                    currentWeekNumber: currentWeek,
                    journeyStructure: structure,
                    allProgress: allProgress,
                    allRecords: sessionRecords,
                    daysPerWeek: profile?.daysPerWeek ?? 4,
                    modelContext: modelContext
                )
            } catch {
                print("Next week generation failed: \(error)")
            }
            isGeneratingNextWeek = false
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: Date())
    }

    private func formatDuration(_ seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60) min" : "\(seconds)s"
    }

    private func exerciseLabel(_ ex: JourneyExercise) -> String {
        if ex.durationSeconds > 0 {
            let mins = ex.durationSeconds / 60
            let secs = ex.durationSeconds % 60
            let timeStr = mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
            return "\(ex.sets) × \(timeStr)"
        } else if ex.reps > 0 {
            return "\(ex.sets) × \(ex.reps)"
        } else {
            return "\(ex.sets) sets"
        }
    }
}
