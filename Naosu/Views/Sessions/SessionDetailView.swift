import SwiftUI

struct SessionDetailView: View {
    let record: SessionRecord

    @Environment(\.dismiss) private var dismiss

    // MARK: - Derived
    private var exercises: [CompletedExerciseRecord] { record.decodedExercises }
    private var badge: (label: String, color: Color) {
        switch record.formScore {
        case 81...: return ("Great", .green)
        case 60...80: return ("Good", .orange)
        default: return ("Fair", .red)
        }
    }

    var body: some View {
        ZStack {
            Color.naosuBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // HEADER
                    headerSection

                    // THREE STAT CARDS
                    HStack(spacing: 12) {
                        statCard(value: "\(record.totalReps)", label: "Total reps")
                        statCard(value: "\(record.formScore)%", label: "Form score", accent: true)
                        statCard(value: "\(exercises.count)", label: "Exercises")
                    }

                    // EXERCISE BREAKDOWN
                    exerciseBreakdownCard

                    // AI NOTES
                    aiNotesCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Sessions")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color.naosuAccent)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                scorePill
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.sessionTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.naosuTextPrimary)

            HStack(spacing: 8) {
                Text(formattedDate)
                dotSep
                Text("Week \(record.weekNumber) · Day \(record.dayNumber)")
                dotSep
                Text(record.formattedDuration)
            }
            .font(.system(size: 13))
            .foregroundStyle(.naosuTextTertiary)
        }
    }

    // MARK: - Score Pill

    private var scorePill: some View {
        Text(badge.label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(badge.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(badge.color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Stat Cards

    @ViewBuilder
    private func statCard(value: String, label: String, accent: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(accent ? Color.naosuAccent : .naosuTextPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.naosuTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.naosuSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.naosuBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Exercise Breakdown

    private var exerciseBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EXERCISE BREAKDOWN")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.naosuTextTertiary)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                if exercises.isEmpty {
                    Text("No exercise data recorded.")
                        .font(.subheadline)
                        .foregroundStyle(.naosuTextSecondary)
                        .padding(.vertical, 16)
                } else {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, ex in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.naosuTextPrimary)
                            }
                            Spacer()
                            Text("\(ex.reps) reps")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.naosuAccent)
                        }
                        .padding(.vertical, 13)

                        if index < exercises.count - 1 {
                            Divider()
                                .background(Color.naosuDivider)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.naosuSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.naosuBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - AI Notes

    private var aiNotesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI NOTES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.naosuTextTertiary)

            Text("Good session overall. Keep focusing on controlled movements for better form scores next session.")
                .font(.system(size: 14))
                .foregroundStyle(.naosuTextSecondary)
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.naosuSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.naosuBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: record.completedAt)
    }

    private var dotSep: some View {
        Text("·")
            .foregroundStyle(.naosuTextTertiary)
            .font(.system(size: 11))
    }
}
