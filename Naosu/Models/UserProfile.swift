import Foundation
import SwiftData

@Model
class UserProfile {
    var userId: String
    var name: String
    var age: Int
    var weight: Double
    var height: Double
    var sex: String
    var goal: String
    var hasInjury: Bool
    var injuredAreas: [String]
    var injuryDescription: String
    var injuryDocumentData: Data?
    var trainingLocation: String
    var daysPerWeek: Int
    var fitnessLevel: String
    var additionalNotes: String
    var createdAt: Date
    /// Timestamp set during onboarding when the journey is first generated.
    var joinedAt: Date
    /// Current week number in the user's journey (1-based).
    var currentWeek: Int
    /// Current progress-based day within the journey (1-based, not calendar).
    var currentDay: Int

    init(
        userId: String,
        name: String,
        age: Int,
        weight: Double,
        height: Double,
        sex: String,
        goal: String,
        hasInjury: Bool,
        injuredAreas: [String],
        injuryDescription: String,
        injuryDocumentData: Data? = nil,
        trainingLocation: String,
        daysPerWeek: Int,
        fitnessLevel: String,
        additionalNotes: String,
        joinedAt: Date = Date(),
        currentWeek: Int = 1,
        currentDay: Int = 1
    ) {
        self.userId = userId
        self.name = name
        self.age = age
        self.weight = weight
        self.height = height
        self.sex = sex
        self.goal = goal
        self.hasInjury = hasInjury
        self.injuredAreas = injuredAreas
        self.injuryDescription = injuryDescription
        self.injuryDocumentData = injuryDocumentData
        self.trainingLocation = trainingLocation
        self.daysPerWeek = daysPerWeek
        self.fitnessLevel = fitnessLevel
        self.additionalNotes = additionalNotes
        self.createdAt = Date()
        self.joinedAt = joinedAt
        self.currentWeek = currentWeek
        self.currentDay = currentDay
    }
}
