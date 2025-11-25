import SwiftUI

// MARK: - Detailed Bar Annotation

struct DetailedBarAnnotation: View {
    let date: Date
    let data: [GroupedDataPoint]
    let metric: any MetricProvider
    let colors: [Color]
    let timePeriod: TimePeriod

    private var totalCount: Int {
        data.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.count }
    }

    private var dayData: [GroupedDataPoint] {
        data.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            // Header with date and total
            HStack {
                Text(formatDate(date))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)

                Spacer()

                Text("Total: \(totalCount)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(CloveColors.secondaryText)
            }

            // Breakdown by type
            if !dayData.isEmpty {
                VStack(spacing: CloveSpacing.xsmall) {
                    ForEach(dayData.sorted(by: { $0.value < $1.value }), id: \.id) { point in
                        BreakdownRow(
                            point: point,
                            total: totalCount,
                            metric: metric,
                            color: getColor(for: point)
                        )
                    }
                }
            }
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(CloveColors.primaryText.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    private func getColor(for point: GroupedDataPoint) -> Color {
        let range = metric.valueRange ?? 1...5
        let index = Int(point.numericValue - range.lowerBound)
        return colors[safe: index] ?? .gray
    }

    private func formatDate(_ date: Date) -> String {
        switch timePeriod {
        case .week, .month:
            return date.formatted(.dateTime.month(.abbreviated).day(.twoDigits))
        case .threeMonth, .sixMonth:
            return date.formatted(.dateTime.month(.abbreviated).day(.twoDigits).year(.twoDigits))
        case .year, .allTime:
            return date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        }
    }
}

// MARK: - Breakdown Row

struct BreakdownRow: View {
    let point: GroupedDataPoint
    let total: Int
    let metric: any MetricProvider
    let color: Color

    private var percentage: Double {
        total > 0 ? (Double(point.count) / Double(total)) * 100 : 0
    }

    var body: some View {
        HStack(spacing: CloveSpacing.small) {
            // Color indicator
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            // Type label
            Text(formatValueLabel(point.value))
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(CloveColors.primaryText)

            Spacer()

            // Count and percentage
            HStack(spacing: 4) {
                Text("\(point.count)")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(color)

                Text("(\(String(format: "%.0f", percentage))%)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
    }

    private func formatValueLabel(_ value: String) -> String {
        guard let doubleValue = Double(value) else { return value }
        return metric.formatValue(doubleValue)
    }
}
