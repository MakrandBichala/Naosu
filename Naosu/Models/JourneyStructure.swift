import Foundation
import SwiftData

// MARK: - SwiftData Model

@Model
class JourneyStructure {
    var userId: String
    var totalWeeks: Int
    var currentWeek: Int
    var currentDay: Int     // progress-based index, not calendar day
    var phases: Data        // [JourneyPhase] encoded as JSON
    var createdAt: Date
    var lastUpdatedAt: Date

    init(
        userId: String,
        totalWeeks: Int,
        currentWeek: Int = 1,
        currentDay: Int = 1,
        phases: [JourneyPhase]
    ) {
        self.userId = userId
        self.totalWeeks = totalWeeks
        self.currentWeek = currentWeek
        self.currentDay = currentDay
        self.phases = (try? JSONEncoder().encode(phases)) ?? Data()
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
    }

    var decodedPhases: [JourneyPhase] {
        get { (try? JSONDecoder().decode([JourneyPhase].self, from: phases)) ?? [] }
        set { phases = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// The phase that is currently active.
    var currentPhase: JourneyPhase? {
        decodedPhases.first(where: { $0.isCurrent })
    }
}

// MARK: - Journey Phase (Codable value type)

struct JourneyPhase: Codable, Identifiable {
    var id: String
    var name: String
    var startWeek: Int
    var endWeek: Int
    var goal: String
    var weeklyFocus: [String]
    var isCompleted: Bool
    var isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, startWeek, endWeek, goal, weeklyFocus, isCompleted, isCurrent
    }
}

extension JourneyPhase {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = (try? c.decode(String.self,   forKey: .id))          ?? UUID().uuidString
        name        = (try? c.decode(String.self,   forKey: .name))        ?? "Phase"
        startWeek   = (try? c.decode(Int.self,      forKey: .startWeek))   ?? 1
        endWeek     = (try? c.decode(Int.self,      forKey: .endWeek))     ?? 4
        goal        = (try? c.decode(String.self,   forKey: .goal))        ?? ""
        weeklyFocus = (try? c.decode([String].self, forKey: .weeklyFocus)) ?? []
        isCompleted = (try? c.decode(Bool.self,     forKey: .isCompleted)) ?? false
        isCurrent   = (try? c.decode(Bool.self,     forKey: .isCurrent))   ?? false
    }
}
