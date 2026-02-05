import SwiftUI

struct PeriodDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let period: Period

    var body: some View {
        NavigationView {
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
                        // Summary card
                        summaryCard
                            .padding(.horizontal, CloveSpacing.large)
                            .padding(.top, CloveSpacing.medium)

                        // Day-by-day details
                        VStack(spacing: CloveSpacing.medium) {
                            HStack {
                                Text("Daily Details")
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                    .foregroundStyle(CloveColors.primaryText)

                                Spacer()
                            }
                            .padding(.horizontal, CloveSpacing.large)

                            ForEach(Array(period.entries.enumerated()), id: \.element.id) { index, entry in
                                DayDetailCard(entry: entry, dayNumber: index + 1)
                                    .padding(.horizontal, CloveSpacing.large)
                            }
                        }
                        .padding(.vertical, CloveSpacing.medium)
                    }
                    .padding(.bottom, CloveSpacing.xlarge)
                }
            }
            .navigationTitle("Period Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("Period Details")
                            .font(.headline)

                        Text("BETA")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.pink)
                            )
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.pink)
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: CloveSpacing.medium) {
            // Date range
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Period Duration")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)

                    Text(formatDateRange())
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Days")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)

                    Text("\(period.duration)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.pink)
                }
            }

            Divider()

            // Stats grid
            HStack(spacing: CloveSpacing.large) {
                // Average flow
                VStack(spacing: CloveSpacing.small) {
                    ZStack {
                        Circle()
                            .fill(averageFlowColor().opacity(0.1))
                            .frame(width: 50, height: 50)

                        Image(systemName: "drop.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(averageFlowColor())
                    }

                    Text("Avg Flow")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)

                    Text(averageFlowText())
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                }
                .frame(maxWidth: .infinity)

                // Cramps days
                VStack(spacing: CloveSpacing.small) {
                    ZStack {
                        Circle()
                            .fill(CloveColors.error.opacity(0.1))
                            .frame(width: 50, height: 50)

                        Image(systemName: crampsDays() > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(crampsDays() > 0 ? CloveColors.error : CloveColors.success)
                    }

                    Text("Cramps")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)

                    Text("\(crampsDays())/\(period.duration) days")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                }
                .frame(maxWidth: .infinity)

                // Heaviest day
                VStack(spacing: CloveSpacing.small) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 50, height: 50)

                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.purple)
                    }

                    Text("Heaviest")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)

                    Text("Day \(heaviestDay())")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
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

    private func averageFlowText() -> String {
        let avgFlow = period.averageFlow

        if avgFlow <= 1.5 {
            return "Spotting"
        } else if avgFlow <= 2.5 {
            return "Light"
        } else if avgFlow <= 3.5 {
            return "Medium"
        } else if avgFlow <= 4.5 {
            return "Heavy"
        } else {
            return "Very Heavy"
        }
    }

    private func crampsDays() -> Int {
        period.entries.filter { $0.hasCramps }.count
    }

    private func heaviestDay() -> Int {
        guard let heaviest = period.entries.enumerated().max(by: { $0.element.flow.numericValue < $1.element.flow.numericValue }) else {
            return 1
        }
        return heaviest.offset + 1
    }
}

// MARK: - Day Detail Card

struct DayDetailCard: View {
    let entry: Cycle
    let dayNumber: Int

    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            // Day number badge
            VStack(spacing: 4) {
                Text("Day")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(CloveColors.secondaryText)

                Text("\(dayNumber)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.pink)
            }
            .frame(width: 50)

            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                // Date
                Text(formatDate(entry.date))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)

                // Flow level
                HStack(spacing: CloveSpacing.small) {
                    ZStack {
                        Circle()
                            .fill(flowColor(for: entry.flow).opacity(0.1))
                            .frame(width: 28, height: 28)

                        Image(systemName: flowIcon(for: entry.flow))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(flowColor(for: entry.flow))
                    }

                    Text(entry.flow.displayName)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }

                // Badges
                HStack(spacing: CloveSpacing.small) {
                    if entry.isStartOfCycle {
                        SmallBadge(text: "First Day", color: Color.pink)
                    }

                    if entry.hasCramps {
                        SmallBadge(text: "Cramps", color: CloveColors.error)
                    }
                }
            }

            Spacer()
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(flowColor(for: entry.flow).opacity(0.15), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func flowColor(for flow: FlowLevel) -> Color {
        switch flow {
        case .spotting: return .pink.opacity(0.6)
        case .light: return .pink
        case .medium: return .red
        case .heavy: return .red.opacity(0.9)
        case .veryHeavy: return .purple
        }
    }

    private func flowIcon(for flow: FlowLevel) -> String {
        switch flow {
        case .spotting: return "drop"
        case .light: return "drop.fill"
        case .medium: return "drop.fill"
        case .heavy: return "drop.fill"
        case .veryHeavy: return "drop.fill"
        }
    }
}

// MARK: - Small Badge

struct SmallBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

#Preview {
    let samplePeriod = Period(
        startDate: Date().addingTimeInterval(-7 * 24 * 60 * 60),
        duration: 5,
        entries: [
            Cycle(date: Date().addingTimeInterval(-7 * 24 * 60 * 60), flow: .medium, isStartOfCycle: true, hasCramps: true),
            Cycle(date: Date().addingTimeInterval(-6 * 24 * 60 * 60), flow: .heavy, isStartOfCycle: false, hasCramps: true),
            Cycle(date: Date().addingTimeInterval(-5 * 24 * 60 * 60), flow: .heavy, isStartOfCycle: false, hasCramps: false),
            Cycle(date: Date().addingTimeInterval(-4 * 24 * 60 * 60), flow: .light, isStartOfCycle: false, hasCramps: false),
            Cycle(date: Date().addingTimeInterval(-3 * 24 * 60 * 60), flow: .spotting, isStartOfCycle: false, hasCramps: false)
        ]
    )

    return PeriodDetailSheet(period: samplePeriod)
}
