import SwiftUI

struct ExerciseDetailView: View {
    let exercise: JourneyExercise
    let sectionTitle: String
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.naosuBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    handleBar
                        .padding(.bottom, 20)

                    headerSection
                        .padding(.bottom, 20)

                    VStack(alignment: .leading, spacing: 14) {
                        if !exercise.notes.isEmpty {
                            notesCard
                        }

                        if let cues = exercise.poseInstruction?.formCues, !cues.isEmpty {
                            formCuesCard(cues: cues)
                        }

                        stepByStepCard

                        if !exercise.muscleTargets.isEmpty {
                            muscleTargetsCard
                        }

                        restTimeCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Handle Bar

    private var handleBar: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.naosuBorder)
                .frame(width: 36, height: 4)
            Spacer()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.naosuTextPrimary)

                Text(sectionTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.naosuTextTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(exerciseLabel(exercise))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.naosuAccent)
                Text(exercise.durationSeconds > 0 ? "sets × duration" : "sets × reps")
                    .font(.system(size: 10))
                    .foregroundStyle(.naosuTextTertiary)
            }
        }
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.naosuAccent)
            Text(exercise.notes)
                .font(.system(size: 13))
                .italic()
                .foregroundStyle(.naosuTextSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.naosuAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.naosuAccent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Form Cues Card

    @ViewBuilder
    private func formCuesCard(cues: [String]) -> some View {
        detailCard {
            sectionLabel("Form cues")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(cues, id: \.self) { cue in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.naosuAccent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 5)
                        Text(cue)
                            .font(.system(size: 13))
                            .foregroundStyle(.naosuTextSecondary)
                            .lineSpacing(2)
                    }
                }
            }
        }
    }

    // MARK: - Step-by-Step Card

    private var stepByStepCard: some View {
        detailCard {
            sectionLabel("How to do it")

            if exercise.stepByStep.isEmpty {
                Text("Instructions not available for this exercise.")
                    .font(.system(size: 13))
                    .italic()
                    .foregroundStyle(.naosuTextTertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(exercise.stepByStep.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.naosuAccentLight)
                                    .overlay(
                                        Circle().stroke(Color.naosuAccent, lineWidth: 1)
                                    )
                                    .frame(width: 22, height: 22)
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.naosuAccent)
                            }
                            .padding(.top, 1)

                            Text(step)
                                .font(.system(size: 13))
                                .foregroundStyle(.naosuTextSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 8)

                        if index < exercise.stepByStep.count - 1 {
                            Divider().background(Color.naosuBorder)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Muscle Targets Card

    private var muscleTargetsCard: some View {
        detailCard {
            sectionLabel("Muscle targets")

            FlowLayout(spacing: 8) {
                ForEach(exercise.muscleTargets, id: \.self) { muscle in
                    Text(muscle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.naosuAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.naosuAccentLight)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.naosuAccent, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Rest Time Card

    private var restTimeCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Rest between sets")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.naosuTextTertiary)
                    .textCase(.uppercase)
                    .tracking(0.3)
                Text("60 seconds")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.naosuTextPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(exercise.sets) sets")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.naosuTextPrimary)
                if exercise.durationSeconds > 0 {
                    Text("\(formatDuration(exercise.durationSeconds)) each")
                        .font(.system(size: 12))
                        .foregroundStyle(.naosuTextSecondary)
                } else {
                    Text("\(exercise.reps) reps each")
                        .font(.system(size: 12))
                        .foregroundStyle(.naosuTextSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.naosuAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.naosuAccent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.naosuSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.naosuBorder, lineWidth: 1)
            )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.naosuTextTertiary)
    }

    private func formatDuration(_ seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60) min" : "\(seconds)s"
    }

    private func exerciseLabel(_ ex: JourneyExercise) -> String {
        if ex.durationSeconds > 0 {
            let mins = ex.durationSeconds / 60
            let secs = ex.durationSeconds % 60
            let timeStr = mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
            return "\(ex.sets) × \(timeStr)"
        } else if ex.reps > 0 {
            return "\(ex.sets) × \(ex.reps)"
        } else {
            return "\(ex.sets) sets"
        }
    }
}
