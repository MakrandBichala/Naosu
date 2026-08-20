@preconcurrency import SwiftUI
@preconcurrency import AVFoundation
@preconcurrency import Vision
import SwiftData
import UIKit

// MARK: - CameraExerciseView

struct CameraExerciseView: View {
    let session: DaySession
    var incomplete: IncompleteSession? = nil
    /// When provided (resume path), only these exercises are shown.
    /// Nil / empty means a fresh session — all exercises in the day are used.
    var remainingExercises: [JourneyExercise]? = nil

    enum SessionState { case idle, active, complete }

    // MARK: - Session State
    @State private var sessionState: SessionState = .idle
    @State private var currentExerciseIndex = 0
    @State private var repCount = 0                    // reps in current set
    @State private var completedRepsThisExercise = 0   // cumulative across sets
    @State private var currentSet = 1
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?
    @State private var autoSaveTimer: Timer?
    @State private var completedExercises: [CompletedExercise] = []
    @State private var showSetComplete = false
    @State private var setCompleteRestSeconds = 0
    @State private var formFeedback: FormFeedback = .none
    @State private var detectedPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @State private var cameraManager = CameraManager()
    @State private var showExitDialog = false
    /// For `usesTimedHoldPerSet` exercises: seconds into the current set (auto-completes at goal).
    @State private var secondsElapsedInCurrentSet: Int = 0
    /// Cancels scheduled auto-advance if the user taps Next/Finish before the delay elapses.
    @State private var pendingAutoAdvanceToken: UUID?

    // MARK: - SwiftData
    @Query private var allJourneyPlans: [JourneyPlan]

    @Query private var profiles: [UserProfile]
    @Query private var allProgress: [DayProgress]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Palette (always-dark camera UI)
    private let bgColor = Color(red: 13/255, green: 13/255, blue: 13/255)
    private let cardBgLight = Color.white.opacity(0.05)
    private let borderCol = Color.white.opacity(0.08)
    private let chipUnselectedBg = Color.black.opacity(0.4)
    private let chipUnselectedBorder = Color.white.opacity(0.15)
    private let textSecondary = Color.white.opacity(0.5)
    private let textTertiary = Color.white.opacity(0.25)
    private let accentLight = Color(red: 204/255, green: 120/255, blue: 92/255).opacity(0.15)

    // MARK: - Derived
    /// Uses pre-filtered remaining exercises when provided, otherwise all exercises in the day.
    private var exercises: [JourneyExercise] {
        if let r = remainingExercises, !r.isEmpty { return r }
        return session.sections.flatMap { $0.exercises }
    }

    /// DayProgress record for the current session day (used to track exercise completion).
    private var currentDayProgress: DayProgress? {
        allProgress.first {
            $0.userId == LocalAuthManager.shared.userId &&
            $0.weekNumber == weekNumber &&
            $0.dayNumber == session.dayNumber
        }
    }
    private var currentExercise: JourneyExercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }
    private var userName: String { profiles.first?.name ?? "there" }
    private var timeString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
    private var isLastExercise: Bool { currentExerciseIndex >= exercises.count - 1 }

    /// See `JourneyExercise.effectiveRepsPerSetGoal` — handles reps vs seconds encoding.
    private var effectiveRepsPerSet: Int {
        currentExercise?.effectiveRepsPerSetGoal ?? 1
    }

    private var activeTargetStatTitle: String {
        guard let e = currentExercise else { return "Target" }
        return e.usesTimedHoldPerSet ? "Hold" : "Target"
    }

    private var activeTargetStatValue: String {
        guard let e = currentExercise else { return "—" }
        if e.usesTimedHoldPerSet {
            return formatDuration(e.timedHoldDurationSeconds)
        }
        return "\(e.effectiveRepsPerSetGoal)"
    }

    private var targetSets: Int { max(currentExercise?.sets ?? 1, 1) }
    private var allSetsDone: Bool { currentSet > targetSets }
    private var totalCompletedReps: Int { completedExercises.reduce(0) { $0 + $1.reps } }
    /// Must match the signed-in user’s current week (not `allJourneyPlans.first`, which can be another user’s plan).
    private var weekNumber: Int {
        let uid = LocalAuthManager.shared.userId
        return allJourneyPlans.first(where: { $0.userId == uid && $0.isCurrentWeek })?.weekNumber ?? 1
    }
    private var nextButtonEnabled: Bool { completedRepsThisExercise >= 1 }

    // MARK: - Body

    var body: some View {
        Group {
            if session.isRestDay || exercises.isEmpty {
                restDayView
            } else {
                switch sessionState {
                case .idle: idleView
                case .active: activeView
                case .complete: completeView
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Don’t auto-lock while this screen is up: camera + prep + recording, until you leave
            // (Save & resume later, Discard session, or Done on the summary).
            if !session.isRestDay, !exercises.isEmpty {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            cameraManager = CameraManager()
            cameraManager.onPoseDetected = { observation in
                processPose(observation)
            }
            cameraManager.requestPermissionAndConfigure()
            if let inc = incomplete {
                restoreFromIncomplete(inc)
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            cameraManager.isAnalyzing = false
            stopTimer()
            stopAutoSave()
        }
        .confirmationDialog("End session?", isPresented: $showExitDialog) {
            Button("Save & resume later") {
                saveIncompleteSession()
                cameraManager.isAnalyzing = false
                stopTimer()
                stopAutoSave()
                dismiss()
            }
            Button("Discard session", role: .destructive) {
                deleteIncompleteSession()
                cameraManager.isAnalyzing = false
                stopTimer()
                stopAutoSave()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Rest Day

    private var restDayView: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.naosuAccent)
                Text("Rest day — no exercises today")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }

    // MARK: - State 1: Idle

    private var idleView: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // TOP BAR
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TODAY'S SESSION")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(textTertiary)
                        Text(session.sessionTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text("Day \(session.dayNumber) · Week \(weekNumber)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // EXERCISE CHIPS
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                            chipButton(
                                text: exercise.name,
                                selected: index == currentExerciseIndex
                            ) {
                                currentExerciseIndex = index
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)

                Spacer()

                // CENTER placeholder
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.naosuAccent, lineWidth: 2)
                            .frame(width: 120, height: 120)
                        Image(systemName: "figure.run")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.naosuAccent)
                    }
                    Text("Step into frame")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(textSecondary)
                    Text("Camera will activate when you start")
                        .font(.system(size: 12))
                        .foregroundStyle(textTertiary)
                }

                Spacer()

                // EXERCISE DETAIL CARD
                if let exercise = currentExercise {
                    idleDetailCard(exercise: exercise)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                // BOTTOM BUTTON
                Button(action: startSession) {
                    Text("Start session")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.naosuAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func idleDetailCard(exercise: JourneyExercise) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.system(size: 12))
                    .foregroundStyle(textTertiary)
                    .lineLimit(3)
            }

            if let cues = exercise.poseInstruction?.formCues, !cues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(cues, id: \.self) { cue in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.naosuAccent)
                                .frame(width: 4, height: 4)
                            Text(cue)
                                .font(.system(size: 11))
                                .foregroundStyle(textTertiary)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                detailPill(text: "\(max(exercise.sets, 1)) sets")
                if exercise.usesTimedHoldPerSet {
                    detailPill(text: formatDuration(exercise.timedHoldDurationSeconds))
                } else if exercise.reps > 0 {
                    detailPill(text: "\(exercise.reps) reps")
                } else if exercise.durationSeconds > 0 {
                    detailPill(text: formatDuration(exercise.durationSeconds))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBgLight)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderCol, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func detailPill(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.naosuAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accentLight)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func chipButton(text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .white : textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? AnyShapeStyle(Color.naosuAccent) : AnyShapeStyle(chipUnselectedBg))
                .overlay(
                    Capsule()
                        .stroke(selected ? Color.clear : chipUnselectedBorder, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - State 2: Active

    private var activeView: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
            SkeletonOverlayView(points: detectedPoints)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // TOP BAR (floating)
                HStack {
                    if let ex = currentExercise {
                        Text(ex.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .overlay(Capsule().stroke(borderCol, lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    // Stop → triggers exit dialog
                    Button {
                        showExitDialog = true
                    } label: {
                        Text("Stop")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .overlay(Capsule().stroke(borderCol, lineWidth: 1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // REP COUNTER (or hold timer for second-based sets)
                VStack(spacing: 4) {
                    if let ex = currentExercise, ex.usesTimedHoldPerSet {
                        Text("\(secondsElapsedInCurrentSet)")
                            .font(.system(size: 72, weight: .heavy))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 8)
                        Text("/ \(ex.timedHoldDurationSeconds)s hold")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(textSecondary)
                        Text("TIME")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(textTertiary)
                    } else {
                        Text("\(repCount)")
                            .font(.system(size: 72, weight: .heavy))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 8)
                        Text("REPS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(textTertiary)
                    }
                }

                if showSetComplete {
                    Text("Set complete! Rest \(setCompleteRestSeconds) seconds")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .overlay(Capsule().stroke(borderCol, lineWidth: 1))
                        .clipShape(Capsule())
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .scale))
                }

                Spacer()

                // BOTTOM OVERLAY
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        statCard(value: "\(currentSet)", label: "Set")
                        statCard(value: activeTargetStatValue, label: activeTargetStatTitle)
                        statCard(value: timeString, label: "Time")
                    }

                    feedbackBanner

                    Button {
                        logRepManually()
                    } label: {
                        Text((currentExercise?.usesTimedHoldPerSet == true) ? "Finish set (manual)" : "Log rep (manual)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.naosuAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderCol, lineWidth: 1))
                    }

                    Button(action: advanceExercise) {
                        Text(isLastExercise ? "Finish →" : "Next exercise →")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(nextButtonEnabled ? .white.opacity(0.7) : .white.opacity(0.25))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                allSetsDone
                                    ? AnyShapeStyle(Color.naosuAccent)
                                    : AnyShapeStyle(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(allSetsDone ? Color.clear : borderCol, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!nextButtonEnabled)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderCol, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var feedbackBanner: some View {
        let (bg, dot): (Color, Color) = {
            switch formFeedback {
            case .good:
                return (Color(red: 0, green: 200/255, blue: 100/255).opacity(0.15),
                        Color(red: 0, green: 200/255, blue: 100/255))
            case .adjust:
                return (Color(red: 1, green: 150/255, blue: 0).opacity(0.15),
                        Color(red: 1, green: 150/255, blue: 0))
            case .danger:
                return (Color(red: 1, green: 50/255, blue: 50/255).opacity(0.15),
                        Color(red: 1, green: 50/255, blue: 50/255))
            case .none:
                return (Color.white.opacity(0.08), Color.white.opacity(0.4))
            }
        }()
        HStack(spacing: 10) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(formFeedback.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderCol, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - State 3: Complete

    private var completeView: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 20)

                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(accentLight)
                    RoundedRectangle(cornerRadius: 20).stroke(Color.naosuAccent, lineWidth: 2)
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color.naosuAccent)
                }
                .frame(width: 88, height: 88)

                VStack(spacing: 6) {
                    Text("Session complete")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Great work today, \(userName)")
                        .font(.system(size: 14))
                        .foregroundStyle(textTertiary)
                }

                HStack(spacing: 10) {
                    summaryCard(value: "\(totalCompletedReps)", label: "Total reps")
                    summaryCard(value: "\(max(elapsedSeconds / 60, 0))m", label: "Duration")
                    summaryCard(value: "\(completedExercises.count)", label: "Exercises")
                }
                .padding(.horizontal, 20)

                if !completedExercises.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EXERCISES DONE")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(textTertiary)

                        VStack(spacing: 10) {
                            ForEach(completedExercises) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Text("\(item.reps) reps")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.naosuAccent)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBgLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14).stroke(borderCol, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                }

                Spacer()

                Button(action: completeSessionAndDismiss) {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.naosuAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func summaryCard(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(cardBgLight)
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(borderCol, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Session Actions

    private func startSession() {
        cameraManager.requestPermissionAndConfigure()
        cameraManager.isAnalyzing = true
        sessionState = .active
        formFeedback = .none
        detectedPoints = [:]
        secondsElapsedInCurrentSet = 0
        PoseAnalyzer.resetRepState()
        startTimer()
        startAutoSave()
    }

    private func advanceExercise() {
        pendingAutoAdvanceToken = nil
        guard nextButtonEnabled else { return }
        transitionAfterFinishingCurrentExercise()
    }

    /// After all sets for this exercise are done: go to next exercise, or end session on last exercise.
    private func transitionAfterFinishingCurrentExercise() {
        if let ex = currentExercise {
            completedExercises.append(CompletedExercise(name: ex.name, reps: completedRepsThisExercise))
            markCurrentExerciseComplete(exercise: ex)
        }
        if isLastExercise {
            cameraManager.isAnalyzing = false
            stopTimer()
            stopAutoSave()
            withAnimation(.easeInOut(duration: 0.25)) {
                sessionState = .complete
            }
        } else {
            currentExerciseIndex += 1
            repCount = 0
            completedRepsThisExercise = 0
            currentSet = 1
            secondsElapsedInCurrentSet = 0
            formFeedback = .none
            PoseAnalyzer.resetRepState()
        }
    }

    /// Marks a single exercise as complete in the DayProgress record.
    private func markCurrentExerciseComplete(exercise: JourneyExercise) {
        guard let dp = currentDayProgress else { return }
        JourneyManager.shared.markExerciseComplete(
            exerciseId: exercise.id,
            dayProgress: dp,
            modelContext: modelContext
        )
    }

    private func completeSessionAndDismiss() {
        let dp = currentDayProgress

        // Accumulate reps: this session + any already saved from a prior partial session
        let accumulatedReps = totalCompletedReps + (dp?.totalCompletedReps ?? 0)

        // 0. Mark the day complete in DayProgress (80% threshold check)
        let isDayComplete: Bool
        if let dp {
            isDayComplete = JourneyManager.shared.markDayComplete(
                dayProgress: dp,
                completedReps: accumulatedReps,
                modelContext: modelContext
            )
        } else {
            isDayComplete = false
        }

        // 1. Remove any pending incomplete save for this user
        deleteIncompleteSession()

        // 2. Create a SessionRecord
        let exercisesData = (try? JSONEncoder().encode(
            completedExercises.map { CompletedExerciseRecord(name: $0.name, reps: $0.reps) }
        )) ?? Data()

        let record = SessionRecord(
            userId: LocalAuthManager.shared.userId,
            sessionTitle: session.sessionTitle,
            weekNumber: weekNumber,
            dayNumber: session.dayNumber,
            exercises: exercisesData,
            totalReps: accumulatedReps,
            formScore: 100,
            durationSeconds: elapsedSeconds,
            isComplete: isDayComplete
        )
        modelContext.insert(record)

        // 3. Also persist a SavedSession for backward-compat with Dashboard
        let saved = SavedSession(
            exercise: completedExercises.map(\.name).joined(separator: ", ").nilIfEmpty ?? session.sessionTitle,
            reps: accumulatedReps,
            formScore: 100,
            durationSeconds: elapsedSeconds,
            userId: LocalAuthManager.shared.userId
        )
        modelContext.insert(saved)

        try? modelContext.save()

        // 4. Log to backend
        Task {
            try? await APIClient.shared.logSession(request: SessionLogRequest(
                userId: LocalAuthManager.shared.userId,
                exercise: completedExercises.map(\.name).joined(separator: ", ").nilIfEmpty ?? session.sessionTitle,
                reps: accumulatedReps,
                formScore: 100,
                durationSeconds: elapsedSeconds
            ))
        }

        dismiss()
    }

    /// When pose detection misses reps, the user can still progress (avoids a disabled “Next” forever).
    /// For timed holds (`effectiveRepsPerSet == 1`), one tap completes the rep target for the set.
    private func logRepManually() {
        guard sessionState == .active, currentExercise != nil else { return }
        let needed = effectiveRepsPerSet
        if needed == 1 {
            repCount = 1
        } else {
            repCount += 1
        }
        completedRepsThisExercise += 1
        checkSetCompletion()
    }

    private func processPose(_ observation: VNHumanBodyPoseObservation) {
        guard sessionState == .active else { return }
        guard let ex = currentExercise else { return }
        let analyzer = PoseAnalyzer(exercise: ex, observation: observation)
        self.detectedPoints = analyzer.extractKeyPoints()
        // One angle sample per frame — shared by form feedback + rep counter (avoids double-smoothing glitch).
        analyzer.commitPrimaryAngleSampleForCurrentFrame()
        self.formFeedback = analyzer.analyzeFeedback()
        if analyzer.checkRepCompletion(currentCount: repCount) {
            repCount += 1
            completedRepsThisExercise += 1
            checkSetCompletion()
        }
    }

    private func checkSetCompletion() {
        let needed = effectiveRepsPerSet
        guard repCount >= needed else { return }
        secondsElapsedInCurrentSet = 0
        let isFinalSet = currentSet >= targetSets
        currentSet += 1
        repCount = 0
        PoseAnalyzer.resetRepState()
        if !isFinalSet {
            setCompleteRestSeconds = 30
            withAnimation(.easeInOut(duration: 0.2)) { showSetComplete = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.2)) { showSetComplete = false }
            }
        } else {
            // All sets done for this exercise → move on after a short beat (or user can tap Next sooner).
            let token = UUID()
            pendingAutoAdvanceToken = token
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard pendingAutoAdvanceToken == token else { return }
                pendingAutoAdvanceToken = nil
                transitionAfterFinishingCurrentExercise()
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in onSessionSecondTick() }
        }
    }

    /// Session clock + per-set hold timer (seconds-based exercises auto-complete when hold time is reached).
    private func onSessionSecondTick() {
        elapsedSeconds += 1
        guard sessionState == .active else { return }
        guard let ex = currentExercise, ex.usesTimedHoldPerSet else { return }
        guard !showSetComplete else { return }
        let goal = ex.timedHoldDurationSeconds
        secondsElapsedInCurrentSet += 1
        guard secondsElapsedInCurrentSet >= goal else { return }
        secondsElapsedInCurrentSet = 0
        repCount = effectiveRepsPerSet
        completedRepsThisExercise += 1
        checkSetCompletion()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Auto-Save

    private func startAutoSave() {
        stopAutoSave()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in saveIncompleteSession() }
        }
    }

    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    private func saveIncompleteSession() {
        do {
            let uid = LocalAuthManager.shared.userId
            // Remove existing snapshots for this user
            let descriptor = FetchDescriptor<IncompleteSession>()
            let existing = try modelContext.fetch(descriptor)
            for item in existing where item.userId == uid {
                modelContext.delete(item)
            }
            // Encode current state
            let dayData = (try? JSONEncoder().encode(session)) ?? Data()
            let exData = (try? JSONEncoder().encode(
                completedExercises.map { CompletedExerciseRecord(name: $0.name, reps: $0.reps) }
            )) ?? Data()

            let snap = IncompleteSession(
                userId: uid,
                sessionTitle: session.sessionTitle,
                daySession: dayData,
                completedExercises: exData,
                currentExerciseIndex: currentExerciseIndex,
                currentRepCount: repCount,
                currentSet: currentSet,
                elapsedSeconds: elapsedSeconds
            )
            modelContext.insert(snap)
        } catch {
            print("Auto-save failed: \(error)")
        }
    }

    private func deleteIncompleteSession() {
        do {
            let uid = LocalAuthManager.shared.userId
            let descriptor = FetchDescriptor<IncompleteSession>()
            let existing = try modelContext.fetch(descriptor)
            for item in existing where item.userId == uid {
                modelContext.delete(item)
            }
        } catch {
            print("Delete incomplete session failed: \(error)")
        }
    }

    // MARK: - Resume

    private func restoreFromIncomplete(_ inc: IncompleteSession) {
        currentExerciseIndex = inc.currentExerciseIndex
        repCount = inc.currentRepCount
        completedRepsThisExercise = inc.currentRepCount
        currentSet = inc.currentSet
        elapsedSeconds = inc.elapsedSeconds

        if let decoded = try? JSONDecoder()
            .decode([CompletedExerciseRecord].self, from: inc.completedExercises) {
            completedExercises = decoded.map { CompletedExercise(name: $0.name, reps: $0.reps) }
        }

        // Jump straight into active state
        startSession()
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60) min" : "\(seconds)s"
    }
}

// MARK: - String helper

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Completed Exercise (in-memory, camera session only)

struct CompletedExercise: Identifiable, Codable {
    var id: UUID
    let name: String
    let reps: Int

    init(name: String, reps: Int) {
        self.id = UUID()
        self.name = name
        self.reps = reps
    }
}

// MARK: - Form Feedback

enum FormFeedback {
    case good
    case adjust(String)
    case danger(String)
    case none

    var message: String {
        switch self {
        case .good: return "Movement detected — keep going"
        case .adjust(let joint): return "Adjust your \(joint)"
        case .danger(let msg): return "Stop — \(msg)"
        case .none: return "Get ready"
        }
    }

    var color: Color {
        switch self {
        case .good: return .green
        case .adjust: return .orange
        case .danger: return .red
        case .none: return .gray
        }
    }

    var icon: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .adjust: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        case .none: return "figure.stand"
        }
    }
}

// MARK: - Camera Manager (unchanged)

@Observable
class CameraManager: NSObject, @unchecked Sendable {
    nonisolated(unsafe) let captureSession = AVCaptureSession()
    var onPoseDetected: ((VNHumanBodyPoseObservation) -> Void)?
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
     nonisolated(unsafe) private let processingQueue = DispatchQueue(label: "pose.processing")
    nonisolated(unsafe) private var isConfigured = false
    nonisolated(unsafe) var isAnalyzing = false

    func requestPermissionAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async { self.configure() }
                }
            }
        default:
            break
        }
    }

    func configure() {
        if isConfigured { start(); return }
        isConfigured = true
        captureSession.sessionPreset = .high
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
            connection.isVideoMirrored = true
        }
        start()
    }

    func start() {
        guard !captureSession.isRunning else { return }
        processingQueue.async { [weak self] in self?.captureSession.startRunning() }
    }

    func stop() {
        guard captureSession.isRunning else { return }
        processingQueue.async { [weak self] in self?.captureSession.stopRunning() }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard self.isAnalyzing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let observation = request.results?.first else { return }
        Task { @MainActor [weak self] in self?.onPoseDetected?(observation) }
    }
}

// MARK: - Camera Preview UIViewRepresentable (unchanged)

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer?.frame = uiView.bounds
    }
}

class PreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
