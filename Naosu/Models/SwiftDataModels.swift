import Foundation
import SwiftData

@Model
class SavedSession {
    var exercise: String
    var reps: Int
    var formScore: Int
    var durationSeconds: Int
    var date: Date
    var userId: String

    init(exercise: String, reps: Int, formScore: Int, durationSeconds: Int, userId: String) {
        self.exercise = exercise
        self.reps = reps
        self.formScore = formScore
        self.durationSeconds = durationSeconds
        self.date = Date()
        self.userId = userId
    }
}
