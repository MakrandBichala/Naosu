import SwiftUI
import Charts
import SwiftData

// MARK: - DashboardView

struct DashboardView: View {

    // MARK: - Queries
    @Query(sort: \SessionRecord.completedAt, order: .reverse)
    private var allRecords: [SessionRecord]

    @Query(filter: #Predicate<JourneyPlan> { $0.isCurrentWeek })
    private var plans: [JourneyPlan]

    @Query private var journeyStructures: [JourneyStructure]
    @Query private var allProgress: [DayProgress]

    // MARK: - Derived data
    private var userId: String { AuthManager.shared.userId }
    private var records: [SessionRecord] { allRecords.filter { $0.userId == userId } }
    private var currentPlan: JourneyPlan? { plans.first(where: { $0.userId == userId }) }

    private var journeyStructure: JourneyStructure? {
        journeyStructures.first(where: { $0.userId == userId })
    }

    private var phases: [JourneyPhase] { journeyStructure?.decodedPhases ?? [] }

    private var currentPhase: JourneyPhase? { phases.first(where: { $0.isCurrent }) }

    // Aggregate stats
    private var sessionsThisWeek: Int {
        allProgress.filter {
            $0.userId == userId &&
            $0.weekNumber == (journeyStructure?.currentWeek ?? currentPlan?.weekNumber ?? 1) &&
            $0.isCompleted && !$0.isRestDay
        }.count
    }

    private var avgScore: Int {
        guard !records.isEmpty else { return 0 }
        return records.map(\.formScore).reduce(0, +) / records.count
    }
    private var totalReps: Int { records.map(\.totalReps).reduce(0, +) }
    private var totalSeconds: Int { records.map(\.durationSeconds).reduce(0, +) }
    private var formattedTime: String {
        guard totalSeconds > 0 else { return "0m" }
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }

    // Streak (calendar-based)
    private var streakCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sessionDates = Set(records.map { calendar.startOfDay(for: $0.completedAt) })
        var streak = 0
        var check = today
        while sessionDates.contains(check) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return streak
    }

    // Weekly reps chart
    private var weekDays: [DayRepsData] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else { return [] }
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else {
                return DayRepsData(label: labels[offset], reps: 0, isToday: false)
            }
            let reps = records
                .filter { calendar.isDate($0.completedAt, inSameDayAs: day) }
                .map(\.totalReps).reduce(0, +)
            return DayRepsData(label: labels[offset], reps: reps, isToday: calendar.isDateInToday(day))
        }
    }

    private var weekDateRange: String {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today),
              let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: monday)) – \(fmt.string(from: sunday))"
    }

    // Form score trend (chronological, max 10)
    private var trendPoints: [TrendPoint] {
        Array(records.reversed().enumerated().prefix(10)).map {
            TrendPoint(id: $0.offset + 1, score: $0.element.formScore)
        }
    }

    private var trendIndicator: (label: String, color: Color) {
        guard trendPoints.count >= 2 else { return ("→ Steady", .orange) }
        let first = trendPoints.first!.score
        let last  = trendPoints.last!.score
        let pct = Double(last - first) / Double(max(first, 1)) * 100
        if pct > 5  { return ("↑ Improving", .green) }
        if pct < -5 { return ("↓ Declining", .red) }
        return ("→ Steady", .orange)
    }

    private var overallProgress: Double {
        guard let structure = journeyStructure, structure.totalWeeks > 0 else {
            return min(Double(currentPlan?.weekNumber ?? 1) / 12.0, 1.0)
        }
        return min(Double(structure.currentWeek - 1) / Double(structure.totalWeeks), 1.0)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.naosuBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    statCardsRow
                    weeklyRepsCard
                    formScoreTrendCard
                    journeyRoadmapCard
                    aiInsightCard
                    recentSessionsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                let weekNum = journeyStructure?.currentWeek ?? currentPlan?.weekNumber
                let phaseName = currentPhase?.name ?? currentPlan?.phase.capitalized
                if let w = weekNum {
                    Text("Week \(w)\(phaseName.map { " · \($0)" } ?? "")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.naosuTextTertiary)
                }
                Text("Progress")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.naosuTextPrimary)
            }
            Spacer()
            // Streak pill
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                Text("\(streakCount) day streak")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.naosuAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.naosuAccentLight)
            .overlay(
                Capsule().stroke(Color.naosuAccent.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
    }

    // MARK: - Stat Cards

    private var statCardsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                StatCard(title: "Sessions",  value: "\(sessionsThisWeek)", icon: "flame.fill",   color: .naosuAccent)
                StatCard(title: "Avg form",  value: "\(avgScore)%",     icon: "star.fill",      color: .naosuAccent)
                StatCard(title: "Total reps",value: "\(totalReps)",     icon: "repeat",         color: .naosuAccent)
                StatCard(title: "Time",      value: formattedTime,      icon: "clock.fill",     color: .naosuAccent)
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }

    // MARK: - Weekly Reps Chart

    private var weeklyRepsCard: some View {
        dashCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Reps this week")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.naosuTextPrimary)
                Spacer()
                Text(weekDateRange)
                    .font(.system(size: 12))
                    .foregroundStyle(.naosuTextTertiary)
            }

            if weekDays.allSatisfy({ $0.reps == 0 }) {
                emptyChartPlaceholder(height: 140)
            } else {
                Chart(weekDays) { day in
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Reps", day.reps == 0 ? 2 : day.reps)
                    )
                    .foregroundStyle(day.reps == 0
                        ? AnyShapeStyle(Color.naosuBorder)
                        : AnyShapeStyle(Color.naosuAccent.gradient))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                            .foregroundStyle(Color.naosuTextTertiary)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 140)
            }
        }
    }

    // MARK: - Form Score Trend

    private var formScoreTrendCard: some View {
        dashCard {
            let (tLabel, tColor) = trendIndicator

            HStack(alignment: .firstTextBaseline) {
                Text("Form score trend")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.naosuTextPrimary)
                Spacer()
                Text(tLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tColor)
            }

            if trendPoints.isEmpty {
                emptyChartPlaceholder(height: 120)
            } else {
                Chart(trendPoints) { point in
                    AreaMark(
                        x: .value("Session", point.id),
                        y: .value("Score",   point.score)
                    )
                    .foregroundStyle(Color.naosuAccent.opacity(0.08))

                    LineMark(
                        x: .value("Session", point.id),
                        y: .value("Score",   point.score)
                    )
                    .foregroundStyle(Color.naosuAccent)
                    .symbol {
                        Circle()
                            .fill(Color.naosuAccent)
                            .frame(width: 6, height: 6)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.naosuBorder)
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(Color.naosuTextTertiary)
                    }
                }
                .frame(height: 120)

                // Below-chart labels
                let first = trendPoints.first!.score
                let last  = trendPoints.last!.score
                HStack {
                    Text("Started at \(first)%")
                        .font(.system(size: 11))
                        .foregroundStyle(.naosuTextTertiary)
                    Spacer()
                    Text("Now at \(last)%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.naosuAccent)
                }
            }
        }
    }

    // MARK: - Journey Roadmap

    private var journeyRoadmapCard: some View {
        dashCard {
            Text("Your journey")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.naosuTextPrimary)

            if phases.isEmpty {
                Text("Generate your journey to see your roadmap.")
                    .font(.system(size: 13))
                    .foregroundStyle(.naosuTextTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(phases) { phase in
                        HStack(alignment: .top, spacing: 12) {

                            // Dot + connecting line
                            VStack(spacing: 0) {
                                ZStack {
                                    if phase.isCurrent {
                                        Circle()
                                            .stroke(Color.naosuAccent, lineWidth: 2)
                                            .frame(width: 16, height: 16)
                                    }
                                    Circle()
                                        .fill(phase.isCurrent
                                            ? Color.naosuAccent
                                            : phase.isCompleted
                                                ? Color.naosuAccent.opacity(0.4)
                                                : Color.naosuBorder)
                                        .frame(width: 10, height: 10)
                                }
                                .frame(width: 16, height: 16)

                                if phase.id != phases.last?.id {
                                    Rectangle()
                                        .fill(phase.isCompleted
                                            ? Color.naosuAccent.opacity(0.3)
                                            : Color.naosuBorder)
                                        .frame(width: 1.5)
                                        .frame(minHeight: 28)
                                }
                            }
                            .padding(.top, 2)

                            // Phase info
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(phase.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(
                                            phase.isCurrent
                                                ? Color.naosuAccent
                                                : phase.isCompleted
                                                    ? .naosuTextTertiary
                                                    : .naosuTextSecondary)

                                    if phase.isCompleted {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.naosuAccent.opacity(0.6))
                                    }

                                    if phase.isCurrent {
                                        Text("Current")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Color.naosuAccent)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.naosuAccentLight)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(phase.goal)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.naosuTextTertiary)

                                Text("Week \(phase.startWeek)–\(phase.endWeek)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.naosuTextTertiary)
                                    .opacity(0.7)
                            }
                            .padding(.bottom, phase.id == phases.last?.id ? 0 : 14)

                            Spacer()
                        }
                    }
                }
            }

            // Overall progress bar
            let currentWeek = journeyStructure?.currentWeek ?? currentPlan?.weekNumber ?? 1
            let totalWeeks  = journeyStructure?.totalWeeks  ?? 12
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Overall progress")
                        .font(.system(size: 12))
                        .foregroundStyle(.naosuTextSecondary)
                    Spacer()
                    Text("Week \(currentWeek) of \(totalWeeks)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.naosuAccent)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.naosuBorder)
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.naosuAccent)
                            .frame(width: geo.size.width * overallProgress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - AI Insight

    private var aiInsightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI INSIGHT · THIS WEEK")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.naosuAccent)

            Text("Your form has improved consistently this week. Keep focusing on controlled movements and your next phase will unlock soon.")
                .font(.system(size: 14))
                .foregroundStyle(.naosuTextPrimary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.naosuAccentLight)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.naosuAccent.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Recent Sessions

    private var recentSessionsCard: some View {
        dashCard {
            HStack {
                Text("Recent sessions")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.naosuTextPrimary)
                Spacer()
                NavigationLink {
                    SessionsView()
                } label: {
                    Text("See all")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.naosuAccent)
                }
            }

            if records.isEmpty {
                Text("No sessions yet. Start your first workout!")
                    .font(.subheadline)
                    .foregroundStyle(.naosuTextSecondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(records.prefix(3).enumerated()), id: \.element.id) { idx, record in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.sessionTitle)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.naosuTextPrimary)
                                    .lineLimit(1)
                                Text(record.completedAt, style: .date)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.naosuTextTertiary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(record.totalReps) reps")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.naosuTextPrimary)
                                Text("\(record.formScore)%")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.naosuAccent)
                            }
                        }
                        .padding(.vertical, 11)

                        if idx < min(records.count, 3) - 1 {
                            Divider().background(Color.naosuDivider)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func dashCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(16)
            .background(Color.naosuSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.naosuBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func emptyChartPlaceholder(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.naosuBorder.opacity(0.4))
            Text("No data yet")
                .font(.system(size: 13))
                .foregroundStyle(.naosuTextTertiary)
        }
        .frame(height: height)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.naosuTextPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.naosuTextTertiary)
        }
        .frame(width: 100)
        .padding(10)
        .background(Color.naosuSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.naosuBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Chart Data Models

private struct DayRepsData: Identifiable {
    let id: String      // day label acts as stable id
    let label: String
    let reps: Int
    let isToday: Bool

    init(label: String, reps: Int, isToday: Bool) {
        self.id = label
        self.label = label
        self.reps = reps
        self.isToday = isToday
    }
}

private struct TrendPoint: Identifiable {
    let id: Int
    let score: Int
}

// MARK: - String helper

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Legacy SummaryCard (kept for binary compatibility)
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        StatCard(title: title, value: value, icon: icon, color: color)
    }
}
