import SwiftUI

struct CycleOverviewView: View {
    @State private var periods: [Period] = []
    @State private var cyclePrediction: CyclePrediction? = nil
    @State private var selectedPeriod: Period? = nil
    @State private var showPredictionDisclaimer: Bool = false

    private let cycleRepo = CycleRepo.shared
    private let cycleManager = CycleManager()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.pink.opacity(0.02),
                    CloveColors.background,
                    Color.pink.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: CloveSpacing.large) {
                    // Prediction Card
                    predictionCard
                        .padding(.horizontal, CloveSpacing.large)
                        .padding(.top, CloveSpacing.medium)

                    // Period History
                    if periods.isEmpty {
                        emptyStateView
                            .padding(.horizontal, CloveSpacing.large)
                    } else {
                        VStack(spacing: CloveSpacing.medium) {
                            // Section header
                            HStack {
                                Text("Period History")
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                    .foregroundStyle(CloveColors.primaryText)

                                Spacer()

                                Text("\(periods.count)")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Color.pink)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.pink.opacity(0.1))
                                    )
                            }
                            .padding(.horizontal, CloveSpacing.large)

                            // Period cards
                            ForEach(periods) { period in
                                PeriodCard(period: period) {
                                    selectedPeriod = period
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                                .padding(.horizontal, CloveSpacing.large)
                            }
                        }
                        .padding(.vertical, CloveSpacing.medium)
                    }
                }
                .padding(.bottom, CloveSpacing.xlarge)
            }
        }
        .navigationTitle("Cycle Overview")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadData()
        }
        .sheet(item: $selectedPeriod) { period in
            PeriodDetailSheet(period: period)
        }
        .alert("Period Prediction", isPresented: $showPredictionDisclaimer) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Period predictions are estimates based on your past cycle patterns and are not medical advice. Actual cycle timing can vary due to stress, health changes, and other factors. Consult a healthcare professional for medical concerns.")
        }
    }

    private var predictionCard: some View {
        VStack(spacing: CloveSpacing.medium) {
            HStack {
                HStack(spacing: CloveSpacing.small) {
                    ZStack {
                        Circle()
                            .fill(Color.pink.opacity(0.1))
                            .frame(width: 40, height: 40)

                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.pink)
                    }

                    Text("Next Period")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                }

                Spacer()

                Button(action: {
                    showPredictionDisclaimer = true
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }

            if let prediction = cyclePrediction {
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    HStack(spacing: CloveSpacing.small) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.pink)

                        Text("Predicted Start:")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)

                        Text(formatDate(prediction.startDate))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(CloveColors.primaryText)
                    }

                    HStack(spacing: CloveSpacing.small) {
                        Image(systemName: "clock")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.pink)

                        Text("Expected Duration:")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)

                        Text("\(prediction.length) days")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(CloveColors.primaryText)
                    }

                    // Days until
                    if let daysUntil = daysUntilPrediction(prediction.startDate) {
                        HStack(spacing: CloveSpacing.small) {
                            Image(systemName: "hourglass")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.pink)

                            if daysUntil == 0 {
                                Text("Expected to start today")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Color.pink)
                            } else if daysUntil > 0 {
                                Text("In \(daysUntil) day\(daysUntil == 1 ? "" : "s")")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Color.pink)
                            } else {
                                Text("\(-daysUntil) day\(daysUntil == -1 ? "" : "s") overdue")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(CloveColors.error)
                            }
                        }
                    }
                }
                .padding(CloveSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(Color.pink.opacity(0.05))
                )
            } else {
                VStack(spacing: CloveSpacing.small) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.5))

                    Text("Not enough data yet")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.primaryText)

                    Text("Track at least 2 periods to see predictions")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(CloveSpacing.large)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(CloveColors.secondaryText.opacity(0.05))
                )
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: CloveSpacing.xlarge) {
            VStack(spacing: CloveSpacing.large) {
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Circle()
                        .fill(Color.pink.opacity(0.05))
                        .frame(width: 100, height: 100)

                    Text("🩸")
                        .font(.system(size: 48))
                }

                VStack(spacing: CloveSpacing.medium) {
                    Text("No Period History")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)

                    VStack(spacing: CloveSpacing.small) {
                        Text("Your period history will appear here")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)

                        Text("Start tracking in the Today tab to build your cycle history")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText.opacity(0.8))
                    }
                    .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, CloveSpacing.xlarge)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }

    private func loadData() {
        // Load all cycles
        let allCycles = cycleRepo.getAllCycles()

        // Group into periods
        periods = groupIntoPeriods(allCycles)

        // Load prediction
        cyclePrediction = cycleManager.getNextCycle()
    }

    private func groupIntoPeriods(_ cycles: [Cycle]) -> [Period] {
        guard !cycles.isEmpty else { return [] }

        let calendar = Calendar.current
        let sortedCycles = cycles.sorted { $0.date < $1.date }

        var periods: [Period] = []
        var currentPeriodEntries: [Cycle] = []
        var lastDate: Date? = nil

        for cycle in sortedCycles {
            let cycleDate = calendar.startOfDay(for: cycle.date)

            // Check if this is a new period (either isStartOfCycle or gap in dates)
            let isNewPeriod: Bool
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: cycleDate).day ?? 0
                isNewPeriod = cycle.isStartOfCycle || daysBetween > 1
            } else {
                isNewPeriod = true
            }

            if isNewPeriod && !currentPeriodEntries.isEmpty {
                // Save the current period
                if let firstEntry = currentPeriodEntries.first {
                    periods.append(Period(
                        startDate: firstEntry.date,
                        duration: currentPeriodEntries.count,
                        entries: currentPeriodEntries
                    ))
                }
                currentPeriodEntries = []
            }

            currentPeriodEntries.append(cycle)
            lastDate = cycleDate
        }

        // Add the last period
        if !currentPeriodEntries.isEmpty, let firstEntry = currentPeriodEntries.first {
            periods.append(Period(
                startDate: firstEntry.date,
                duration: currentPeriodEntries.count,
                entries: currentPeriodEntries
            ))
        }

        // Sort periods by start date descending (most recent first)
        return periods.sorted { $0.startDate > $1.startDate }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func daysUntilPrediction(_ date: Date) -> Int? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let predictionDate = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: predictionDate).day
    }
}

// MARK: - Period Model

struct Period: Identifiable {
    let id = UUID()
    let startDate: Date
    let duration: Int
    let entries: [Cycle]

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: duration - 1, to: startDate) ?? startDate
    }

    var hasCramps: Bool {
        entries.contains { $0.hasCramps }
    }

    var averageFlow: Double {
        let flowValues = entries.map { $0.flow.numericValue }
        guard !flowValues.isEmpty else { return 0 }
        return flowValues.reduce(0, +) / Double(flowValues.count)
    }
}

// MARK: - Period Card

struct PeriodCard: View {
    let period: Period
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: CloveSpacing.medium) {
                HStack {
                    // Date and duration
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDateRange())
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(CloveColors.primaryText)

                        Text("\(period.duration) day\(period.duration == 1 ? "" : "s")")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                    }

                    Spacer()

                    // Flow indicator
                    HStack(spacing: CloveSpacing.small) {
                        ZStack {
                            Circle()
                                .fill(averageFlowColor().opacity(0.1))
                                .frame(width: 36, height: 36)

                            Image(systemName: "drop.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(averageFlowColor())
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
                    }
                }

                // Badges
                if period.hasCramps || period.entries.first?.isStartOfCycle == true {
                    HStack(spacing: CloveSpacing.small) {
                        if period.entries.first?.isStartOfCycle == true {
                            Badge(text: "Day 1", color: Color.pink)
                        }

                        if period.hasCramps {
                            Badge(text: "Cramps", color: CloveColors.error)
                        }

                        Spacer()
                    }
                }
            }
            .padding(CloveSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(Color.pink.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        if period.duration == 1 {
            formatter.dateStyle = .medium
            return formatter.string(from: period.startDate)
        } else {
            let start = formatter.string(from: period.startDate)
            let end = formatter.string(from: period.endDate)
            return "\(start) - \(end)"
        }
    }

    private func averageFlowColor() -> Color {
        let avgFlow = period.averageFlow

        if avgFlow <= 1.5 {
            return .pink.opacity(0.6)
        } else if avgFlow <= 2.5 {
            return .pink
        } else if avgFlow <= 3.5 {
            return .red
        } else if avgFlow <= 4.5 {
            return .red.opacity(0.9)
        } else {
            return .purple
        }
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

#Preview {
    NavigationView {
        CycleOverviewView()
    }
}
