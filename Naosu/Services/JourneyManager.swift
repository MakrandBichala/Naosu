import Foundation
import SwiftData

// MARK: - JourneyManager

/// Observable singleton that owns all journey-progression logic:
/// • Finding the current (first incomplete) day across weeks
/// • Marking exercises and days as complete
/// • Calculating completion percentages
@Observable
final class JourneyManager {
    static let shared = JourneyManager()
    private init() {}

    // MARK: - Current Day Resolution

    /// Returns the earliest incomplete non-rest day, together with its parent plan.
    /// Progress records are sorted by weekNumber then dayNumber so the user always
    /// sees the lowest-numbered outstanding day first — i.e. progress-based, not
    /// calendar-based.
    func getCurrentDay(
        plans: [JourneyPlan],
        progress: [DayProgress],
        userId: String
    ) -> (plan: JourneyPlan, day: DaySession)? {
        guard !plans.isEmpty, !progress.isEmpty else { return nil }

        let userPlans = plans.filter { $0.userId == userId }
        let userProgress = progress.filter { $0.userId == userId }

        guard !userPlans.isEmpty, !userProgress.isEmpty else { return nil }

        let sorted = userProgress.sorted {
            if $0.weekNumber != $1.weekNumber { return $0.weekNumber < $1.weekNumber }
            return $0.dayNumber < $1.dayNumber
        }

        guard let incomplete = sorted.first(where: { !$0.isCompleted }) else {
            return nil // every recorded day is complete
        }

        guard let plan = userPlans.first(where: { $0.weekNumber == incomplete.weekNumber })
        else { return nil }

        guard let day = plan.days.first(where: { $0.dayNumber == incomplete.dayNumber })
        else { return nil }

        return (plan, day)
    }

    /// Returns the next incomplete day after the given one (for the "tomorrow" preview).
    func getNextDay(
        after dayNumber: Int,
        inWeek weekNumber: Int,
        plans: [JourneyPlan],
        progress: [DayProgress],
        userId: String
    ) -> DaySession? {
        let sorted = progress
            .filter { $0.userId == userId }
            .sorted {
                if $0.weekNumber != $1.weekNumber { return $0.weekNumber < $1.weekNumber }
                return $0.dayNumber < $1.dayNumber
            }

        // Walk forward from the current position
        let candidates = sorted.filter {
            ($0.weekNumber == weekNumber && $0.dayNumber > dayNumber) ||
            $0.weekNumber > weekNumber
        }

        guard let next = candidates.first(where: { !$0.isCompleted }) else { return nil }

        guard let plan = plans.first(where: {
            $0.weekNumber == next.weekNumber && $0.userId == userId
        }) else { return nil }

        return plan.days.first(where: { $0.dayNumber == next.dayNumber })
    }

    // MARK: - Week Completion

    func isWeekComplete(
        weekNumber: Int,
        progress: [DayProgress],
        userId: String
    ) -> Bool {
        let weekProgress = progress.filter {
            $0.userId == userId && $0.weekNumber == weekNumber
        }
        return !weekProgress.isEmpty && weekProgress.allSatisfy { $0.isCompleted }
    }

    // MARK: - Completion Percentage

    func calculateCompletion(completedReps: Int, totalReps: Int) -> Double {
        guard totalReps > 0 else { return 1.0 }
        return min(1.0, Double(completedReps) / Double(totalReps))
    }

    // MARK: - Day Completion

    /// Saves completed reps, updates `completionPercentage`, and marks the day
    /// complete if ≥ 80 % of planned reps were achieved.
    /// Returns `true` when the day is now complete.
    @discardableResult
    func markDayComplete(
        dayProgress: DayProgress,
        completedReps: Int,
        modelContext: ModelContext
    ) -> Bool {
        let pct = calculateCompletion(
            completedReps: completedReps,
            totalReps: dayProgress.totalPlannedReps
        )
        dayProgress.totalCompletedReps = completedReps
        dayProgress.completionPercentage = pct

        if pct >= 0.8 {
            dayProgress.isCompleted = true
            dayProgress.completedAt = Date()
            try? modelContext.save()
            return true
        }
        try? modelContext.save()
        return false
    }

    // MARK: - Exercise Completion

    /// Returns the decoded list of already-completed exercise IDs for a day.
    func getCompletedExerciseIds(dayProgress: DayProgress) -> [String] {
        dayProgress.completedIds
    }

    /// Appends `exerciseId` to `dayProgress.completedExerciseIds` (idempotent).
    func markExerciseComplete(
        exerciseId: String,
        dayProgress: DayProgress,
        modelContext: ModelContext
    ) {
        var ids = dayProgress.completedIds
        guard !ids.contains(exerciseId) else { return }
        ids.append(exerciseId)
        dayProgress.completedExerciseIds = (try? JSONEncoder().encode(ids)) ?? Data()
        try? modelContext.save()
    }

    // MARK: - Next Week Generation

    func generateNextWeek(
        currentWeekNumber: Int,
        journeyStructure: JourneyStructure,
        allProgress: [DayProgress],
        allRecords: [SessionRecord],
        daysPerWeek: Int,
        modelContext: ModelContext
    ) async throws -> JourneyPlan {
        let userId = LocalAuthManager.shared.userId
        let nextWeek = currentWeekNumber + 1

        // Performance stats for the completed week
        let weekRecords = allRecords.filter {
            $0.userId == userId && $0.weekNumber == currentWeekNumber
        }
        let totalReps = weekRecords.reduce(0) { $0 + $1.totalReps }
        let avgFormScore = weekRecords.isEmpty ? 75 :
            weekRecords.reduce(0) { $0 + $1.formScore } / weekRecords.count
        let sessionsCompleted = allProgress.filter {
            $0.userId == userId &&
            $0.weekNumber == currentWeekNumber &&
            $0.isCompleted && !$0.isRestDay
        }.count

        // Resolve phase and weekly focus for the next week
        let phases = journeyStructure.decodedPhases
        let nextPhase = phases.first { $0.startWeek <= nextWeek && $0.endWeek >= nextWeek }
        let weekIndexInPhase = nextWeek - (nextPhase?.startWeek ?? 1)
        let weeklyFocus = nextPhase?.weeklyFocus[safe: weekIndexInPhase] ?? "Progressive training"

        let notes: String
        if avgFormScore < 70 {
            notes = "User needs more practice, keep difficulty same"
        } else if avgFormScore > 85 {
            notes = "User is doing great, increase difficulty"
        } else {
            notes = "User is progressing well"
        }

        // API call — suspends on APIClient actor
        let weekPlan = try await APIClient.shared.generateNextWeek(
            weekNumber: nextWeek,
            currentPhase: nextPhase?.name ?? "Training",
            phaseGoal: nextPhase?.goal ?? "",
            weeklyFocus: weeklyFocus,
            avgFormScore: Double(avgFormScore),
            totalReps: totalReps,
            sessionsCompleted: sessionsCompleted,
            daysPerWeek: daysPerWeek,
            notes: notes
        )

        // Back on MainActor — safe to touch SwiftData models

        // Mark old plan as done
        let oldPlanDescriptor = FetchDescriptor<JourneyPlan>(
            predicate: #Predicate { $0.weekNumber == currentWeekNumber }
        )
        if let oldPlan = try? modelContext.fetch(oldPlanDescriptor).first(where: { $0.userId == userId }) {
            oldPlan.isCurrentWeek = false
            oldPlan.isCompleted = true
            oldPlan.completedAt = Date()
        }

        // Save new JourneyPlan
        let newPlan = JourneyPlan(
            userId: userId,
            weekNumber: nextWeek,
            phase: weekPlan.phase,
            days: weekPlan.days,
            isCurrentWeek: true,
            weekSummary: weekPlan.weekSummary
        )
        modelContext.insert(newPlan)

        // Create DayProgress records for each day in the new week
        let emptyIds = (try? JSONEncoder().encode([String]())) ?? Data()
        for day in weekPlan.days {
            let progress = DayProgress(
                userId: userId,
                weekNumber: nextWeek,
                dayNumber: day.dayNumber,
                isCompleted: day.isRestDay,
                isRestDay: day.isRestDay,
                completionPercentage: day.isRestDay ? 1.0 : 0.0,
                totalPlannedReps: day.isRestDay ? 0 : calculateTotalReps(day),
                totalCompletedReps: 0,
                completedExerciseIds: emptyIds,
                completedAt: day.isRestDay ? Date() : nil
            )
            modelContext.insert(progress)
        }

        // Update UserProfile
        let profileDescriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let profile = try? modelContext.fetch(profileDescriptor).first {
            profile.currentWeek = nextWeek
            profile.currentDay = 1
        }

        // Update JourneyStructure phase statuses
        var updatedPhases = phases
        for i in updatedPhases.indices {
            updatedPhases[i].isCompleted = updatedPhases[i].endWeek < nextWeek
            updatedPhases[i].isCurrent  = updatedPhases[i].startWeek <= nextWeek
                                       && updatedPhases[i].endWeek   >= nextWeek
        }
        journeyStructure.decodedPhases = updatedPhases
        journeyStructure.currentWeek   = nextWeek
        journeyStructure.lastUpdatedAt = Date()

        try? modelContext.save()
        return newPlan
    }

    private func calculateTotalReps(_ day: DaySession) -> Int {
        day.sections.flatMap(\.exercises).reduce(0) { total, ex in
            total + ex.sets * max(ex.reps, ex.durationSeconds > 0 ? 1 : 0)
        }
    }

    // MARK: - Live Completion Fraction (UI only)

    /// Fraction of exercises completed so far in a day — derived from
    /// `completedExerciseIds` so it reflects partial-session progress before
    /// `markDayComplete` has been called.
    func liveFraction(dayProgress: DayProgress, totalExercises: Int) -> Double {
        guard totalExercises > 0 else { return 1.0 }
        return Double(dayProgress.completedIds.count) / Double(totalExercises)
    }
}

// MARK: - Safe array subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
