import SwiftUI

// MARK: - Custom Chart Legend

struct CustomChartLegend: View {
    let metric: any MetricProvider
    let data: [GroupedDataPoint]
    let colors: [Color]
    @Binding var highlightedType: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
            Text("Legend")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(CloveColors.secondaryText)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: CloveSpacing.xsmall) {
                ForEach(getLegendItems(), id: \.type) { item in
                    LegendRow(
                        item: item,
                        isHighlighted: highlightedType == item.type,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if highlightedType == item.type {
                                    highlightedType = nil
                                } else {
                                    highlightedType = item.type
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(CloveSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.small)
                .fill(CloveColors.card.opacity(0.3))
        )
    }

    private func getLegendItems() -> [LegendItem] {
        let range = metric.valueRange ?? 1...5
        let types = stride(from: range.lowerBound, through: range.upperBound, by: 1.0).map { $0 }

        return types.enumerated().map { index, type in
            // GroupedDataPoint.value is the formatted string from metric.formatValue()
            let formattedValue = metric.formatValue(type)
            let count = data.filter { $0.value == formattedValue }.reduce(0) { $0 + $1.count }
            let total = data.reduce(0) { $0 + $1.count }
            let percentage = total > 0 ? (Double(count) / Double(total)) * 100 : 0

            return LegendItem(
                type: type,
                label: formattedValue,
                color: colors[safe: index] ?? .gray,
                count: count,
                percentage: percentage
            )
        }.filter { $0.count > 0 } // Only show types that have data
    }
}

// MARK: - Supporting Types

struct LegendItem {
    let type: Double
    let label: String
    let color: Color
    let count: Int
    let percentage: Double
}

struct LegendRow: View {
    let item: LegendItem
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    // Color swatch
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .strokeBorder(isHighlighted ? item.color.opacity(0.5) : .clear, lineWidth: 2)
                        )

                    Text(item.label)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.primaryText)
                        .lineLimit(1)
                }

                Text("\(item.count) · \(String(format: "%.0f", item.percentage))%")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? item.color.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isHighlighted ? item.color.opacity(0.3) : .clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Helper Extensions

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview("Bowel Movements Legend") {
    @Previewable @State var highlightedType: Double? = nil

    let mockData = [
        GroupedDataPoint(date: Date(), count: 5, value: "Type 1", numericValue: 1.0),
        GroupedDataPoint(date: Date(), count: 8, value: "Type 2", numericValue: 2.0),
        GroupedDataPoint(date: Date(), count: 12, value: "Type 3", numericValue: 3.0),
        GroupedDataPoint(date: Date(), count: 15, value: "Type 4", numericValue: 4.0),
        GroupedDataPoint(date: Date(), count: 7, value: "Type 5", numericValue: 5.0),
        GroupedDataPoint(date: Date(), count: 3, value: "Type 6", numericValue: 6.0),
        GroupedDataPoint(date: Date(), count: 2, value: "Type 7", numericValue: 7.0)
    ]

    let bowelMetric = BowelMovementMetricProvider()

    let colors: [Color] = [
        Color(hex: "714934"), // Type 1
        Color(hex: "E18E13"), // Type 2
        Color(hex: "B1E16B"), // Type 3
        Color(hex: "22C42D"), // Type 4
        Color(hex: "2A737A"), // Type 5
        Color(hex: "6F039D"), // Type 6
        Color(hex: "960101")  // Type 7
    ]

    CustomChartLegend(
        metric: bowelMetric,
        data: mockData,
        colors: colors,
        highlightedType: $highlightedType
    )
    .padding()
}

#Preview("Mood Legend") {
    @Previewable @State var highlightedType: Double? = nil

    let mockData = [
        GroupedDataPoint(date: Date(), count: 2, value: "1", numericValue: 1.0),
        GroupedDataPoint(date: Date(), count: 5, value: "2", numericValue: 2.0),
        GroupedDataPoint(date: Date(), count: 8, value: "3", numericValue: 3.0),
        GroupedDataPoint(date: Date(), count: 10, value: "4", numericValue: 4.0),
        GroupedDataPoint(date: Date(), count: 6, value: "5", numericValue: 5.0)
    ]

    let moodMetric = MoodMetricProvider()

    let colors: [Color] = [
        Color(hex: "FF6B6B"),
        Color(hex: "4ECDC4"),
        Color(hex: "FFE66D"),
        Color(hex: "95E1D3"),
        Color(hex: "F38181")
    ]

    CustomChartLegend(
        metric: moodMetric,
        data: mockData,
        colors: colors,
        highlightedType: $highlightedType
    )
    .padding()
}
