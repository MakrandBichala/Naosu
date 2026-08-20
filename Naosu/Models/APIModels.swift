import Foundation

// MARK: - Journey Generation

/// Request body for POST /generate-journey (new full-journey endpoint).
struct GenerateJourneyRequest: Codable {
    let name: String
    let age: Int
    let weight: Double
    let height: Double
    let sex: String
    let goal: String
    let hasInjury: Bool
    let injuredAreas: [String]
    let injuryDescription: String
    let trainingLocation: String
    let daysPerWeek: Int
    let fitnessLevel: String
    let additionalNotes: String
}

/// Request body for POST /generate-next-week.
struct GenerateNextWeekRequest: Codable {
    let weekNumber: Int
    let currentPhase: String
    let phaseGoal: String
    let weeklyFocus: String
    let avgFormScore: Double
    let totalReps: Int
    let sessionsCompleted: Int
    let daysPerWeek: Int
    let notes: String
}

// MARK: - Session Logging

struct SessionLogRequest: Codable {
    let userId: String
    let exercise: String
    let reps: Int
    let formScore: Int
    let durationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exercise, reps
        case formScore = "form_score"
        case durationSeconds = "duration_seconds"
    }
}

// MARK: - Progress

struct ProgressResponse: Codable {
    let sessions: [SessionEntry]
    let dailySummary: [DailySummary]

    enum CodingKeys: String, CodingKey {
        case sessions
        case dailySummary = "daily_summary"
    }
}

struct SessionEntry: Codable, Identifiable {
    var id: String { "\(exercise)-\(timestamp)" }
    let userId: String
    let exercise: String
    let reps: Int
    let formScore: Int
    let durationSeconds: Int
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exercise, reps
        case formScore = "form_score"
        case durationSeconds = "duration_seconds"
        case timestamp
    }
}

struct DailySummary: Codable, Identifiable {
    var id: String { date }
    let date: String
    let totalReps: Int
    let avgFormScore: Double

    enum CodingKeys: String, CodingKey {
        case date
        case totalReps = "total_reps"
        case avgFormScore = "avg_form_score"
    }
}
