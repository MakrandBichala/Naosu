import Foundation
import SwiftData

// MARK: - IncompleteSession
// Stores a mid-session snapshot so the user can resume later.

@Model
class IncompleteSession {
    var userId: String
    var sessionTitle: String
    var daySession: Data            // DaySession encoded as JSON
    var completedExercises: Data    // [CompletedExerciseRecord] encoded as JSON
    var currentExerciseIndex: Int
    var currentRepCount: Int
    var currentSet: Int
    var elapsedSeconds: Int
    var savedAt: Date

    init(
        userId: String,
        sessionTitle: String,
        daySession: Data,
        completedExercises: Data,
        currentExerciseIndex: Int,
        currentRepCount: Int,
        currentSet: Int,
        elapsedSeconds: Int
    ) {
        self.userId = userId
        self.sessionTitle = sessionTitle
        self.daySession = daySession
        self.completedExercises = completedExercises
        self.currentExerciseIndex = currentExerciseIndex
        self.currentRepCount = currentRepCount
        self.currentSet = currentSet
        self.elapsedSeconds = elapsedSeconds
        self.savedAt = Date()
    }
}

// MARK: - SessionRecord
// A completed (or stopped-early) session, shown in SessionsView history.

@Model
class SessionRecord {
    var userId: String
    var sessionTitle: String
    var weekNumber: Int
    var dayNumber: Int
    var exercises: Data     // [CompletedExerciseRecord] encoded as JSON
    var totalReps: Int
    var formScore: Int
    var durationSeconds: Int
    var isComplete: Bool
    var completedAt: Date

    init(
        userId: String,
        sessionTitle: String,
        weekNumber: Int,
        dayNumber: Int,
        exercises: Data,
        totalReps: Int,
        formScore: Int,
        durationSeconds: Int,
        isComplete: Bool
    ) {
        self.userId = userId
        self.sessionTitle = sessionTitle
        self.weekNumber = weekNumber
        self.dayNumber = dayNumber
        self.exercises = exercises
        self.totalReps = totalReps
        self.formScore = formScore
        self.durationSeconds = durationSeconds
        self.isComplete = isComplete
        self.completedAt = Date()
    }

    var decodedExercises: [CompletedExerciseRecord] {
        (try? JSONDecoder().decode([CompletedExerciseRecord].self, from: exercises)) ?? []
    }

    var formattedDuration: String {
        if durationSeconds >= 60 {
            let m = durationSeconds / 60
            let s = durationSeconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
        return "\(durationSeconds)s"
    }

    var scoreBadge: (label: String, color: String) {
        switch formScore {
        case 81...: return ("Great", "green")
        case 60...80: return ("Good", "orange")
        default: return ("Fair", "red")
        }
    }
}

// MARK: - CompletedExerciseRecord
// Codable struct used inside IncompleteSession.completedExercises
// and SessionRecord.exercises JSON blobs.

struct CompletedExerciseRecord: Codable, Identifiable {
    var id: UUID
    let name: String
    let reps: Int

    init(id: UUID = UUID(), name: String, reps: Int) {
        self.id = id
        self.name = name
        self.reps = reps
    }
}
