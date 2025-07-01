import SwiftUI
import Charts

struct AnalysisResultsView: View {
    let analysis: CorrelationAnalysis
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            correlationSummaryCard
            dualAxisChartView
            insightsSection
            saveButton
        }
    }

    // MARK: - Correlation Summary

    private var correlationSummaryCard: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("Correlation Results")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)

            HStack(spacing: CloveSpacing.large) {
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Coefficient")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)

                    Text(String(format: "%.3f", analysis.coefficient))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(correlationColor(analysis.coefficient))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: CloveSpacing.small) {
                    Text("\(analysis.correlationDirection) Correlation")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.primaryText)
                        .fontWeight(.semibold)

                    Text(analysis.correlationStrength)
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }

            if analysis.isSignificant {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CloveColors.green)

                    Text("Statistically significant (p < 0.05)")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }
        }
        .padding(CloveSpacing.large)
        .background(cardBackground)
    }

    // MARK: - Chart

    private var dualAxisChartView: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("Dual Metric Chart")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)

            Chart {
                ForEach(Array(analysis.dataPoints.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Date", point.0),
                        y: .value(analysis.primaryMetric.name, point.1)
                    )
                    .foregroundStyle(CloveColors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    LineMark(
                        x: .value("Date", point.0),
                        y: .value(analysis.secondaryMetric.name, normalizeSecondaryValue(point.2))
                    )
                    .foregroundStyle(CloveColors.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3, dash: [5, 5]))
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                    AxisValueLabel()
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }

            HStack(spacing: CloveSpacing.large) {
                HStack(spacing: CloveSpacing.small) {
                    Rectangle()
                        .fill(CloveColors.accent)
                        .frame(width: 20, height: 3)
                    Text(analysis.primaryMetric.name)
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }

                HStack(spacing: CloveSpacing.small) {
                    Rectangle()
                        .fill(CloveColors.blue)
                        .frame(width: 20, height: 3)
                        .overlay(
                            Rectangle()
                                .stroke(CloveColors.blue, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        )
                    Text("\(analysis.secondaryMetric.name) (normalized)")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }

                Spacer()
            }
        }
        .padding(CloveSpacing.large)
        .background(cardBackground)
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("Key Insights")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)

            VStack(spacing: CloveSpacing.small) {
                ForEach(Array(analysis.insights.enumerated()), id: \.offset) { _, insight in
                    HStack(alignment: .top, spacing: CloveSpacing.small) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(CloveColors.accent)
                            .frame(width: 20)

                        Text(insight)
                            .font(CloveFonts.body())
                            .foregroundStyle(CloveColors.primaryText)

                        Spacer()
                    }
                    .padding(.vertical, CloveSpacing.xsmall)
                }
            }
        }
        .padding(CloveSpacing.large)
        .background(cardBackground)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        HStack {
            Spacer()
            Button(action: onSave) {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14))
                    Text("Save Analysis")
                        .font(CloveFonts.body())
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, CloveSpacing.large)
                .padding(.vertical, CloveSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(CloveColors.accent)
                )
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func normalizeSecondaryValue(_ value: Double) -> Double {
        let secondaryValues = analysis.dataPoints.map { $0.2 }
        let primaryValues = analysis.dataPoints.map { $0.1 }

        guard let sMin = secondaryValues.min(),
              let sMax = secondaryValues.max(),
              let pMin = primaryValues.min(),
              let pMax = primaryValues.max(),
              sMax != sMin, pMax != pMin else {
            return value
        }

        let normalized = (value - sMin) / (sMax - sMin)
        return normalized * (pMax - pMin) + pMin
    }

    private func correlationColor(_ coefficient: Double) -> Color {
        let absCoeff = abs(coefficient)
        switch absCoeff {
        case 0.6...:
            return CloveColors.green
        case 0.3..<0.6:
            return CloveColors.accent
        default:
            return CloveColors.secondaryText
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

