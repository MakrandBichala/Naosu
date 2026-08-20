import Foundation
import SwiftData

// MARK: - SwiftData Model

@Model
class JourneyPlan {
    var userId: String
    var weekNumber: Int
    var phase: String
    var daysJSON: Data
    var generatedAt: Date
    var isCurrentWeek: Bool
    /// AI-generated summary of this week's focus and intent.
    var weekSummary: String
    /// Coach notes filled in once the week is fully complete.
    var performanceNotes: String
    /// True once every non-rest day in this week is completed.
    var isCompleted: Bool
    var completedAt: Date?

    init(
        userId: String,
        weekNumber: Int,
        phase: String,
        days: [DaySession],
        isCurrentWeek: Bool = true,
        weekSummary: String = "",
        performanceNotes: String = "",
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.userId = userId
        self.weekNumber = weekNumber
        self.phase = phase
        self.daysJSON = (try? JSONEncoder().encode(days)) ?? Data()
        self.generatedAt = Date()
        self.isCurrentWeek = isCurrentWeek
        self.weekSummary = weekSummary
        self.performanceNotes = performanceNotes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    var days: [DaySession] {
        get { (try? JSONDecoder().decode([DaySession].self, from: daysJSON)) ?? [] }
        set { daysJSON = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// Returns today's session based on day of week (Mon=1 ... Sun=7)
    var todaySession: DaySession? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // Convert: Sunday=1..Saturday=7  →  Monday=1..Sunday=7
        let dayNumber = weekday == 1 ? 7 : weekday - 1
        return days.first(where: { $0.dayNumber == dayNumber })
    }

    /// Returns tomorrow's session
    var tomorrowSession: DaySession? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let todayNum = weekday == 1 ? 7 : weekday - 1
        let tomorrowNum = todayNum == 7 ? 1 : todayNum + 1
        return days.first(where: { $0.dayNumber == tomorrowNum })
    }
}

// MARK: - Codable Structs

struct DaySession: Codable, Identifiable {
    var id: String
    var dayNumber: Int
    var dayLabel: String
    var sessionTitle: String
    var isRestDay: Bool
    var sections: [SessionSection]

    enum CodingKeys: String, CodingKey {
        case id, dayNumber, dayLabel, sessionTitle, isRestDay, sections
    }
}

extension DaySession {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = (try? c.decode(String.self,           forKey: .id))           ?? UUID().uuidString
        dayNumber    = (try? c.decode(Int.self,              forKey: .dayNumber))    ?? 1
        dayLabel     = (try? c.decode(String.self,           forKey: .dayLabel))     ?? ""
        sessionTitle = (try? c.decode(String.self,           forKey: .sessionTitle)) ?? ""
        isRestDay    = (try? c.decode(Bool.self,             forKey: .isRestDay))    ?? false
        sections     = (try? c.decode([SessionSection].self, forKey: .sections))     ?? []
    }
}

struct SessionSection: Codable, Identifiable {
    var id: String
    var title: String
    var exercises: [JourneyExercise]

    enum CodingKeys: String, CodingKey {
        case id, title, exercises
    }
}

extension SessionSection {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = (try? c.decode(String.self,             forKey: .id))        ?? UUID().uuidString
        title     = (try? c.decode(String.self,             forKey: .title))     ?? ""
        exercises = (try? c.decode([JourneyExercise].self,  forKey: .exercises)) ?? []
    }
}

struct JourneyExercise: Codable, Identifiable {
    var id: String
    var name: String
    var sets: Int
    var reps: Int
    var durationSeconds: Int
    var notes: String
    /// Biomechanical rules used by `PoseAnalyzer` for accurate form tracking.
    var poseInstruction: PoseInstruction?
    /// AI-generated step-by-step performance instructions.
    var stepByStep: [String]
    /// Primary muscle groups worked by this exercise.
    var muscleTargets: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, sets, reps, durationSeconds, notes
        case poseInstruction, stepByStep, muscleTargets
    }
}

extension JourneyExercise {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = (try? c.decode(String.self,          forKey: .id))              ?? UUID().uuidString
        name            = (try? c.decode(String.self,          forKey: .name))            ?? "Exercise"
        sets            = (try? c.decode(Int.self,             forKey: .sets))            ?? 1
        reps            = (try? c.decode(Int.self,             forKey: .reps))            ?? 0
        durationSeconds = (try? c.decode(Int.self,             forKey: .durationSeconds)) ?? 0
        notes           = (try? c.decode(String.self,          forKey: .notes))           ?? ""
        poseInstruction = try? c.decode(PoseInstruction.self,  forKey: .poseInstruction)
        stepByStep      = (try? c.decode([String].self,        forKey: .stepByStep))      ?? []
        muscleTargets   = (try? c.decode([String].self,        forKey: .muscleTargets))   ?? []
    }
}

// MARK: - Rep vs time semantics (camera + progress)

extension JourneyExercise {
    /// `true` when each set is defined by **seconds** (hold), not a large rep count.
    /// Covers: `reps == 0` + `durationSeconds`, or the same number in both fields (seconds mis-encoded as reps).
    var usesTimedHoldPerSet: Bool {
        if reps == 0 && durationSeconds > 0 { return true }
        if durationSeconds > 0 && reps == durationSeconds && reps >= 10 { return true }
        return false
    }

    /// Reps counted toward finishing **one set** (timed holds use 1 completion per set).
    var effectiveRepsPerSetGoal: Int {
        if usesTimedHoldPerSet { return 1 }
        if reps == 0 { return 1 }
        return max(1, reps)
    }

    /// Hold length for this set when `usesTimedHoldPerSet` is true.
    var timedHoldDurationSeconds: Int {
        guard usesTimedHoldPerSet else { return 0 }
        return max(1, durationSeconds)
    }
}

// MARK: - Pose Instruction (AI-generated form rules)

struct PoseInstruction: Codable {
    var primaryJoints: [String]
    var movementType: String
    var startAngle: Double
    var endAngle: Double
    var repDirection: String
    var repThreshold: Double
    var formCues: [String]

    enum CodingKeys: String, CodingKey {
        case primaryJoints, movementType, startAngle, endAngle
        case repDirection, repThreshold, formCues
    }
}

extension PoseInstruction {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        primaryJoints = (try? c.decode([String].self, forKey: .primaryJoints)) ?? []
        movementType  = (try? c.decode(String.self,   forKey: .movementType))  ?? "vertical"
        startAngle    = (try? c.decode(Double.self,   forKey: .startAngle))    ?? 180.0
        endAngle      = (try? c.decode(Double.self,   forKey: .endAngle))      ?? 90.0
        repDirection  = (try? c.decode(String.self,   forKey: .repDirection))  ?? "decrease"
        repThreshold  = (try? c.decode(Double.self,   forKey: .repThreshold))  ?? 30.0
        formCues      = (try? c.decode([String].self, forKey: .formCues))      ?? []
    }
}

// MARK: - API Response Types (match Groq JSON output)

/// Top-level response from /generate-journey.
struct FullJourneyAPIResponse: Codable {
    let journeyStructure: JourneyStructureResponse
    let week1Plan: JourneyWeekPlan
}

/// The multi-week roadmap portion of the journey response.
struct JourneyStructureResponse: Codable {
    var totalWeeks: Int
    var phases: [JourneyPhase]

    enum CodingKeys: String, CodingKey { case totalWeeks, phases }
}

extension JourneyStructureResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalWeeks = (try? c.decode(Int.self,           forKey: .totalWeeks)) ?? 12
        phases     = (try? c.decode([JourneyPhase].self, forKey: .phases))    ?? []
    }
}

/// A single week's exercise plan (used for week1Plan and /generate-next-week responses).
struct JourneyWeekPlan: Codable {
    var phase: String
    var weekSummary: String
    var days: [DaySession]

    enum CodingKeys: String, CodingKey { case phase, weekSummary, days }
}

extension JourneyWeekPlan {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        phase       = (try? c.decode(String.self,       forKey: .phase))       ?? ""
        weekSummary = (try? c.decode(String.self,       forKey: .weekSummary)) ?? ""
        days        = (try? c.decode([DaySession].self, forKey: .days))        ?? []
    }
}
