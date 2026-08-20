import Foundation
import SwiftData

// MARK: - SwiftData Model

@Model
class DayProgress {
    var userId: String
    var weekNumber: Int
    var dayNumber: Int          // 1–7
    var isCompleted: Bool
    var isRestDay: Bool
    var completionPercentage: Double    // 0.0 to 1.0
    var totalPlannedReps: Int
    var totalCompletedReps: Int
    var completedExerciseIds: Data      // [String] encoded as JSON
    var sessionRecordId: String?        // links to SessionRecord
    var completedAt: Date?
    var createdAt: Date

    init(
        userId: String,
        weekNumber: Int,
        dayNumber: Int,
        isCompleted: Bool,
        isRestDay: Bool,
        completionPercentage: Double,
        totalPlannedReps: Int,
        totalCompletedReps: Int,
        completedExerciseIds: Data,
        sessionRecordId: String? = nil,
        completedAt: Date? = nil
    ) {
        self.userId = userId
        self.weekNumber = weekNumber
        self.dayNumber = dayNumber
        self.isCompleted = isCompleted
        self.isRestDay = isRestDay
        self.completionPercentage = completionPercentage
        self.totalPlannedReps = totalPlannedReps
        self.totalCompletedReps = totalCompletedReps
        self.completedExerciseIds = completedExerciseIds
        self.sessionRecordId = sessionRecordId
        self.completedAt = completedAt
        self.createdAt = Date()
    }

    /// Decoded list of completed exercise IDs.
    var completedIds: [String] {
        get { (try? JSONDecoder().decode([String].self, from: completedExerciseIds)) ?? [] }
        set { completedExerciseIds = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
