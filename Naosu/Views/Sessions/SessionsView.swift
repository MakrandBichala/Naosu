import SwiftUI
import SwiftData

struct SessionsView: View {
    @Binding var selectedTab: Int

    init(selectedTab: Binding<Int> = .constant(1)) {
        self._selectedTab = selectedTab
    }

    /// Ensures SwiftUI subscribes to cross-tab recording triggers.
    @Bindable private var navigationState = NavigationState.shared

    @Query(sort: \JourneyPlan.weekNumber, order: .reverse)
    private var plans: [JourneyPlan]

    @Query private var allProgress: [DayProgress]

    @Query(sort: \SessionRecord.completedAt, order: .reverse)
    private var sessionRecords: [SessionRecord]

    @Query private var incompleteSessions: [IncompleteSession]

    @State private var showRecording = false
    @State private var cachedDay: DaySession? = nil
    @State private var cachedPlan: JourneyPlan? = nil
    @State private var isLoading = true
    @State private var isNavigating = false
    /// Captured before `NavigationState.reset()` so the camera receives the Workout tab’s “remaining” list.
    @State private var recordingRemainingExercises: [JourneyExercise]? = nil

    private var userId: String { LocalAuthManager.shared.userId }

    private var incompleteForToday: IncompleteSession? {
        incompleteSessions.first { $0.userId == userId }
    }

    private var hasIncomplete: Bool { incompleteForToday != nil }

    private var userRecords: [SessionRecord] {
        sessionRecords.filter { $0.userId == userId }
    }

    var body: some View {
        ZStack {
            Color.naosuBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Text("Sessions")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.naosuTextPrimary)
                    Text("Record and review your workouts")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.naosuTextTertiary)

                    // Today's card
                    if isLoading {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.naosuAccent.opacity(0.3))
                            .frame(height: 160)
                            .overlay(ProgressView().tint(.white))
                    } else if let day = cachedDay, let plan = cachedPlan {
                        todayCard(day: day, plan: plan)
                    } else {
                        emptyTodayCard
                    }

                    // Previous sessions
                    Text("Previous sessions")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.naosuTextPrimary)

                    if userRecords.isEmpty {
                        emptySessionsView
                    } else {
                        ForEach(userRecords.prefix(20)) { record in
                            NavigationLink(destination: SessionDetailView(record: record)) {
                                sessionCard(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .fullScreenCover(isPresented: $showRecording, onDismiss: {
            isNavigating = false
            recordingRemainingExercises = nil
        }) {
            if let day = cachedDay {
                CameraExerciseView(
                    session: day,
                    incomplete: incompleteForToday,
                    remainingExercises: recordingRemainingExercises
                )
            }
        }
        .task {
            await loadTodaySession()
        }
        .onChange(of: allProgress) { _, _ in
            Task { await loadTodaySession() }
        }
        .onChange(of: navigationState.shouldStartRecording) { _, newValue in
            guard newValue, !isNavigating else { return }
            guard cachedDay != nil else {
                navigationState.reset()
                return
            }
            let remaining = navigationState.remainingExercises
            recordingRemainingExercises = remaining.isEmpty ? nil : remaining
            navigationState.reset()
            isNavigating = true
            showRecording = true
        }
    }

    // MARK: - Load today

    @MainActor
    func loadTodaySession() async {
        isLoading = true
        let result = JourneyManager.shared.getCurrentDay(
            plans: plans,
            progress: allProgress,
            userId: userId
        )
        cachedDay = result?.day
        cachedPlan = result?.plan
        isLoading = false
    }

    // MARK: - Today card

    @ViewBuilder
    func todayCard(day: DaySession, plan: JourneyPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today · Week \(plan.weekNumber) Day \(day.dayNumber)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Text(day.sessionTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(spacing: 8) {
                let exCount = day.sections.flatMap { $0.exercises }.count
                infoPill("\(exCount) exercises")
                infoPill(day.isRestDay ? "Rest day" : "~\(estimatedMinutes(day)) min")
                infoPill(plan.phase)
            }

            if !day.isRestDay {
                Button {
                    guard !isNavigating else { return }
                    recordingRemainingExercises = nil
                    isNavigating = true
                    showRecording = true
                } label: {
                    HStack {
                        Text(hasIncomplete ? "Resume session →" : "Start recording →")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.naosuAccent)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                Text("Rest day — enjoy your recovery")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .background(Color.naosuAccent)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty today card

    var emptyTodayCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(Color.naosuTextTertiary)
            Text("No session today")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.naosuTextPrimary)
            Text("Complete your health intake to generate your journey")
                .font(.system(size: 12))
                .foregroundStyle(Color.naosuTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.naosuSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.naosuBorder, lineWidth: 1))
    }

    // MARK: - Empty sessions

    var emptySessionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 36))
                .foregroundStyle(Color.naosuAccent)
            Text("No sessions yet")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.naosuTextPrimary)
            Text("Complete your first session to see it here")
                .font(.system(size: 14))
                .foregroundStyle(Color.naosuTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Session card

    @ViewBuilder
    func sessionCard(record: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.sessionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.naosuTextPrimary)
                    Text(formattedDate(record.completedAt))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.naosuTextTertiary)
                }
                Spacer()
                scorePill(record.formScore)
            }

            HStack(spacing: 16) {
                statItem("\(record.totalReps)", "Reps")
                divider
                statItem(record.formattedDuration, "Duration")
                divider
                statItem("\(record.formScore)%", "Form")
            }
        }
        .padding(14)
        .background(Color.naosuSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.naosuBorder, lineWidth: 1))
    }

    // MARK: - Helpers

    func infoPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.2))
            .clipShape(Capsule())
    }

    func scorePill(_ score: Int) -> some View {
        let (label, color): (String, Color) = score > 80
            ? ("Great", .green)
            : score > 60
            ? ("Good", .orange)
            : ("Fair", .red)
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    func statItem(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.naosuTextPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.naosuTextTertiary)
        }
    }

    var divider: some View {
        Rectangle()
            .fill(Color.naosuBorder)
            .frame(width: 1, height: 28)
    }

    func estimatedMinutes(_ day: DaySession) -> Int {
        let sets = day.sections.flatMap { $0.exercises }
            .reduce(0) { $0 + $1.sets }
        return max(15, sets * 2)
    }

    func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}

#Preview {
    SessionsView(selectedTab: .constant(1))
}
