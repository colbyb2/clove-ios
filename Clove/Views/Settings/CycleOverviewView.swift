import SwiftUI

struct CycleOverviewView: View {
    @State private var periods: [Period] = []
    @State private var cyclePrediction: CyclePrediction? = nil
    @State private var selectedPeriod: Period? = nil
    @State private var showPredictionDisclaimer: Bool = false

    // Assuming these exist in your project based on context
    private let cycleRepo = CycleRepo.shared
    private let cycleManager = CycleManager()

    var body: some View {
        ZStack {
            // cleaner, flat background matching the dashboard
            CloveColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Prediction Card (Hero)
                    predictionCard
                        .padding(.horizontal)
                        .padding(.top, 10)

                    // Period History
                    if periods.isEmpty {
                        emptyStateView
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 16) {
                            // Section header
                            HStack {
                                Text("History")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(CloveColors.primaryText)

                                Spacer()
                                
                                // Subtle count badge
                                Text("\(periods.count) Cycles")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(CloveColors.secondaryText)
                            }
                            .padding(.horizontal)

                            // Period cards
                            ForEach(periods) { period in
                                PeriodCard(period: period) {
                                    selectedPeriod = period
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Cycle")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
        .sheet(item: $selectedPeriod) { period in
            PeriodDetailSheet(period: period)
        }
        .alert("Period Prediction", isPresented: $showPredictionDisclaimer) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Predictions are estimates based on your past cycle patterns. This is not medical advice.")
        }
    }

    // MARK: - Hero Card
    private var predictionCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.purple)
                    
                    Text("Forecast")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
                
                Button(action: { showPredictionDisclaimer = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
                }
            }
            .padding([.horizontal, .top], 16)
            
            Divider().padding(.top, 16).opacity(0) // Spacer

            if let prediction = cyclePrediction {
                HStack(alignment: .bottom) {
                    // Big Countdown
                    VStack(alignment: .leading, spacing: 4) {
                        let days = daysUntilPrediction(prediction.startDate) ?? 0
                        
                        if days > 0 {
                            Text("In \(days) Days")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(CloveColors.primaryText)
                        } else if days == 0 {
                            Text("Expected Today")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.pink)
                        } else {
                            Text("\(-days) Days Late")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(CloveColors.error)
                        }
                        
                        Text(formatDate(prediction.startDate))
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Stat Pill
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Duration")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)
                        
                        Text("~ \(prediction.length) Days")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(CloveColors.primaryText)
                    }
                }
                .padding(20)
                
            } else {
                // Not enough data state
                VStack(spacing: 12) {
                    Text("Not Enough Data")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Log at least 2 full cycles to unlock predictions.")
                        .font(.system(.caption))
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(30)
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CloveColors.card)
                // Subtle border instead of pink fill
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "drop.degreesign.slash") // More abstract icon
                .font(.system(size: 40))
                .foregroundStyle(CloveColors.secondaryText.opacity(0.3))
                .padding(.bottom, 8)

            Text("No History Yet")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)

            Text("Logs from the Today view will appear here.")
                .font(.system(.subheadline))
                .foregroundStyle(CloveColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(CloveColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private func loadData() {
        let allCycles = cycleRepo.getAllCycles()
        periods = groupIntoPeriods(allCycles)
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
            let isNewPeriod: Bool
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: cycleDate).day ?? 0
                isNewPeriod = cycle.isStartOfCycle || daysBetween > 1
            } else {
                isNewPeriod = true
            }

            if isNewPeriod && !currentPeriodEntries.isEmpty {
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
        if !currentPeriodEntries.isEmpty, let firstEntry = currentPeriodEntries.first {
            periods.append(Period(
                startDate: firstEntry.date,
                duration: currentPeriodEntries.count,
                entries: currentPeriodEntries
            ))
        }
        return periods.sorted { $0.startDate > $1.startDate }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
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
// (Kept identical to ensure no breaking changes)
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

// MARK: - Refined Period Card

struct PeriodCard: View {
    let period: Period
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 1. Flow Icon (The only "Pink" part)
                ZStack {
                    Circle()
                        .fill(averageFlowColor().opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "drop.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(averageFlowColor())
                }

                // 2. Main Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDateRange())
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)

                    HStack(spacing: 8) {
                        Text("\(period.duration) Days")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)
                        
                        // Small dot separator
                        if period.hasCramps {
                            Circle().fill(CloveColors.secondaryText.opacity(0.4)).frame(width: 3, height: 3)
                            
                            // Subtle text indicator instead of a loud badge
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.heart.fill")
                                    .font(.system(size: 10))
                                Text("Cramps")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(CloveColors.error.opacity(0.8))
                        }
                    }
                }

                Spacer()

                // 3. Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CloveColors.secondaryText.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(CloveColors.card)
                    // No pink borders, just clean depth
                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        if period.duration == 1 {
            return formatter.string(from: period.startDate)
        } else {
            let start = formatter.string(from: period.startDate)
            let end = formatter.string(from: period.endDate)
            return "\(start) - \(end)"
        }
    }

    private func averageFlowColor() -> Color {
        let avgFlow = period.averageFlow
        // Slightly tweaked colors for dark mode legibility
        if avgFlow <= 1.5 { return .pink.opacity(0.5) }
        else if avgFlow <= 2.5 { return .pink }
        else if avgFlow <= 3.5 { return .red }
        else if avgFlow <= 4.5 { return .red.opacity(0.9) }
        else { return .purple }
    }
}

#Preview {
    CycleOverviewView()
}
