import SwiftUI
import SwiftData

struct WeekCompleteView: View {
    let weekNumber: Int
    let allProgress: [DayProgress]
    let journeyStructure: JourneyStructure?
    let onContinue: () -> Void

    @State private var isGenerating = false
    @State private var generationError: String?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionRecord.completedAt, order: .reverse)
    private var allRecords: [SessionRecord]
    @Query private var profiles: [UserProfile]

    private var userId: String { AuthManager.shared.userId }

    // MARK: - Stats

    private var weekRecords: [SessionRecord] {
        allRecords.filter { $0.userId == userId && $0.weekNumber == weekNumber }
    }

    private var weekSessions: Int {
        allProgress.filter {
            $0.userId == userId &&
            $0.weekNumber == weekNumber &&
            $0.isCompleted &&
            !$0.isRestDay
        }.count
    }

    private var weekTotalReps: Int { weekRecords.reduce(0) { $0 + $1.totalReps } }

    private var weekAvgFormScore: Int {
        guard !weekRecords.isEmpty else { return 0 }
        return weekRecords.reduce(0) { $0 + $1.formScore } / weekRecords.count
    }

    private var weekTotalSeconds: Int { weekRecords.reduce(0) { $0 + $1.durationSeconds } }

    private var weekFormattedTime: String {
        let h = weekTotalSeconds / 3600
        let m = (weekTotalSeconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return m > 0 ? "\(m)m" : "0m"
    }

    // MARK: - Phase Info

    private var currentPhase: JourneyPhase? {
        journeyStructure?.decodedPhases.first {
            $0.startWeek <= weekNumber && $0.endWeek >= weekNumber
        }
    }

    private var isPhaseComplete: Bool { currentPhase?.endWeek == weekNumber }

    private var phaseStartWeek: Int { currentPhase?.startWeek ?? 1 }
    private var phaseEndWeek: Int   { currentPhase?.endWeek   ?? weekNumber }

    private var phaseProgress: Double {
        let range = phaseEndWeek - phaseStartWeek + 1
        guard range > 0 else { return 1.0 }
        return min(Double(weekNumber - phaseStartWeek + 1) / Double(range), 1.0)
    }

    // MARK: - Next Week Info

    private var nextWeekInfo: (focus: String, phaseName: String, isNewPhase: Bool)? {
        guard let structure = journeyStructure else { return nil }
        let nextWeek = weekNumber + 1
        guard nextWeek <= structure.totalWeeks else { return nil }
        let phases = structure.decodedPhases
        let nextPhase = phases.first { $0.startWeek <= nextWeek && $0.endWeek >= nextWeek }
        let isNew = nextPhase?.id != currentPhase?.id
        let idx = nextWeek - (nextPhase?.startWeek ?? 1)
        let focus = nextPhase?.weeklyFocus[safe: idx] ?? "Progressive training"
        return (focus, nextPhase?.name ?? "Training", isNew)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "#0a0a0f").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer(minLength: 56)
                    topSection
                    statsCard
                    phaseProgressCard
                    if let info = nextWeekInfo {
                        nextWeekCard(info: info)
                    }
                    generateButton
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Top Section

    private var topSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.naosuAccent)
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Week \(weekNumber) complete!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("You've finished every session this week.\nTime to level up.")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "#6b6860"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("THIS WEEK")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.naosuAccent)
                Spacer()
            }
            .padding(.bottom, 14)

            HStack(spacing: 0) {
                weekStatItem(value: "\(weekSessions)",         label: "Sessions")
                statDivider
                weekStatItem(value: "\(weekTotalReps)",        label: "Total reps")
                statDivider
                weekStatItem(value: "\(weekAvgFormScore)%",    label: "Avg form")
                statDivider
                weekStatItem(value: weekFormattedTime,         label: "Time")
            }
        }
        .padding(16)
        .background(Color(hex: "#1a1915"))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#3a3830"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statDivider: some View {
        Color(hex: "#3a3830").frame(width: 1, height: 40)
    }

    @ViewBuilder
    private func weekStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color(hex: "#6b6860"))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Phase Progress Card

    private var phaseProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isPhaseComplete {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.naosuAccent)
                    Text("Phase complete!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.naosuAccent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.naosuAccent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.naosuAccent.opacity(0.4), lineWidth: 1)
                )

                if let name = currentPhase?.name {
                    Text("You've completed \(name)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#9b9890"))
                }
            } else {
                Text("Week \(weekNumber) of \(phaseEndWeek) in \(currentPhase?.name ?? "Training")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#f0ede8"))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: "#3a3830"))
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.naosuAccent)
                            .frame(width: geo.size.width * phaseProgress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(Color(hex: "#1a1915"))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#3a3830"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Next Week Card

    @ViewBuilder
    private func nextWeekCard(info: (focus: String, phaseName: String, isNewPhase: Bool)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NEXT WEEK'S FOCUS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#6b6860"))

            Text(info.focus)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "#f0ede8"))
                .lineSpacing(3)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.naosuAccent)
                    .frame(width: 6, height: 6)
                Text(info.isNewPhase
                    ? "New phase: \(info.phaseName)"
                    : "Same phase · \(info.phaseName)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#9b9890"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#1a1915"))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#3a3830"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        VStack(spacing: 12) {
            Button {
                Task { await runGeneration() }
            } label: {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Building your next week...")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("Generate Week \(weekNumber + 1) →")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isGenerating
                    ? Color.naosuAccent.opacity(0.7)
                    : Color.naosuAccent)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isGenerating)

            if let error = generationError {
                VStack(spacing: 8) {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Button("Try again") {
                        Task { await runGeneration() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.naosuAccent)
                }
            }
        }
    }

    // MARK: - Generation Logic

    private func runGeneration() async {
        isGenerating = true
        generationError = nil

        do {
            guard let structure = journeyStructure else {
                throw NSError(
                    domain: "Naosu", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No journey structure found."]
                )
            }
            let daysPerWeek = profiles.first(where: { $0.userId == userId })?.daysPerWeek ?? 4

            _ = try await JourneyManager.shared.generateNextWeek(
                currentWeekNumber: weekNumber,
                journeyStructure: structure,
                allProgress: allProgress,
                allRecords: allRecords,
                daysPerWeek: daysPerWeek,
                modelContext: modelContext
            )

            isGenerating = false
            onContinue()
        } catch {
            isGenerating = false
            generationError = error.localizedDescription
        }
    }
}
