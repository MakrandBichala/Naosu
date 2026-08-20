import Foundation

/// Cross-tab navigation signals. Used when one tab needs to trigger
/// a state change in another tab after a programmatic tab switch.
@Observable
final class NavigationState {
    static let shared = NavigationState()
    private init() {}

    /// Set to true by `TodaySessionView` right before switching to the
    /// Sessions tab. `SessionsView` watches this and auto-pushes
    /// `CameraExerciseView` when it flips true, then resets it.
    var shouldStartRecording = false

    /// The subset of exercises the user still needs to complete today.
    /// Empty means "all exercises" (a fresh session, not a resume).
    /// Populated by `TodaySessionView.switchToSessionsTab()` from the
    /// exercises that are NOT yet in `DayProgress.completedExerciseIds`.
    var remainingExercises: [JourneyExercise] = []

    /// Atomically sets remaining exercises and fires the recording trigger.
    func triggerRecording(exercises: [JourneyExercise] = []) {
        remainingExercises = exercises
        shouldStartRecording = true
    }

    /// Clears all cross-tab navigation state.
    func reset() {
        shouldStartRecording = false
        remainingExercises = []
    }
}
