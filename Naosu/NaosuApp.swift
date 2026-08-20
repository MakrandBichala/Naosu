import SwiftUI
import SwiftData

@main
struct NaosuApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            UserProfile.self,
            JourneyPlan.self,
            JourneyStructure.self,
            DayProgress.self,
            SavedSession.self,
            IncompleteSession.self,
            SessionRecord.self
        ])
    }
}
