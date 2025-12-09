import SwiftUI
import Charts

enum StatisticalTerm: Identifiable {
    case correlationCoefficient
    case pValue
    case statisticalSignificance
    case scatterPlot

    var id: String {
        switch self {
        case .correlationCoefficient: return "coefficient"
        case .pValue: return "pValue"
        case .statisticalSignificance: return "significance"
        case .scatterPlot: return "scatterPlot"
        }
    }

    var title: String {
        switch self {
        case .correlationCoefficient: return "Correlation Coefficient"
        case .pValue: return "P-Value"
        case .statisticalSignificance: return "Statistical Significance"
        case .scatterPlot: return "Scatter Plot"
        }
    }

    var explanation: String {
        switch self {
        case .correlationCoefficient:
            return "A number between -1 and 1 that measures how closely two metrics are related. Values closer to 1 mean they increase together, closer to -1 mean one increases while the other decreases, and closer to 0 means little to no relationship."
        case .pValue:
            return "A measure of how likely it is that the correlation happened by chance. Values below 0.05 (5%) suggest the relationship is real and not random. Lower values indicate stronger evidence of a true relationship."
        case .statisticalSignificance:
            return "When a p-value is below 0.05, we say the result is 'statistically significant,' meaning there's strong evidence that the correlation is real and not just due to random chance."
        case .scatterPlot:
            return "Each point represents a day where both metrics were tracked. The trend line shows the overall relationship direction. Points closer to the line indicate a stronger correlation."
        }
    }
}

struct AnalysisResultsView: View {
    let analysis: CorrelationAnalysis
    let onSave: () -> Void
    @State private var showingTooltip: StatisticalTerm? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            correlationSummaryCard
            scatterPlotView
            dualAxisChartView
            insightsSection
        }
        .sheet(item: $showingTooltip) { term in
            StatisticalTooltipView(term: term)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Correlation Summary

    private var correlationSummaryCard: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            Text("Relationship Summary")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)

            // Main insight in plain English
            VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                HStack(spacing: CloveSpacing.medium) {
                    relationshipIcon
                        .font(.system(size: 32))
                    
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text(relationshipTitle)
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                            .multilineTextAlignment(.leading)
                        
                        Text(relationshipDescription)
                            .font(CloveFonts.body())
                            .foregroundStyle(CloveColors.secondaryText)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                // Strength indicator
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Relationship Strength")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    HStack(spacing: CloveSpacing.small) {
                        strengthMeter
                        Text(strengthDescription)
                            .font(CloveFonts.body())
                            .foregroundStyle(strengthColor)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            // Technical details (collapsible)
            DisclosureGroup("Technical Details") {
                VStack(spacing: CloveSpacing.medium) {
                    HStack {
                        VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                            HStack(spacing: CloveSpacing.xsmall) {
                                Text("Correlation Coefficient")
                                    .font(CloveFonts.small())
                                    .foregroundStyle(CloveColors.secondaryText)
                                Button(action: {
                                    showingTooltip = .correlationCoefficient
                                }) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.shared.accent.opacity(0.6))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            Text(String(format: "%.3f", analysis.coefficient))
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(correlationColor(analysis.coefficient))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: CloveSpacing.xsmall) {
                            HStack(spacing: CloveSpacing.xsmall) {
                                Text("P-Value")
                                    .font(CloveFonts.small())
                                    .foregroundStyle(CloveColors.secondaryText)
                                Button(action: {
                                    showingTooltip = .pValue
                                }) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.shared.accent.opacity(0.6))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            Text(String(format: "%.3f", analysis.pValue))
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(analysis.isSignificant ? CloveColors.green : CloveColors.secondaryText)
                        }
                    }
                    
                    if analysis.isSignificant {
                        HStack(spacing: CloveSpacing.small) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(CloveColors.green)
                            Button(action: {
                                showingTooltip = .statisticalSignificance
                            }) {
                                Text("This relationship is statistically significant")
                                    .font(CloveFonts.small())
                                    .foregroundStyle(CloveColors.secondaryText)
                                    .underline(true, color: Theme.shared.accent.opacity(0.3))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else {
                        HStack(spacing: CloveSpacing.small) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(CloveColors.secondaryText)
                            Button(action: {
                                showingTooltip = .statisticalSignificance
                            }) {
                                Text("This relationship may be due to chance")
                                    .font(CloveFonts.small())
                                    .foregroundStyle(CloveColors.secondaryText)
                                    .underline(true, color: Theme.shared.accent.opacity(0.3))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.top, CloveSpacing.small)
            }
            .font(CloveFonts.small())
            .foregroundStyle(CloveColors.secondaryText)
        }
        .padding(CloveSpacing.large)
        .background(cardBackground)
    }

    // MARK: - Scatter Plot

    private var scatterPlotView: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                Text("Correlation Scatter Plot")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)

                Spacer()

                Button(action: {
                    showingTooltip = .scatterPlot
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.shared.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text("Each point represents a day where both metrics were tracked")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)

            Chart {
                ForEach(Array(analysis.dataPoints.enumerated()), id: \.offset) { index, point in
                    PointMark(
                        x: .value(analysis.primaryMetric.displayName, point.1),
                        y: .value(analysis.secondaryMetric.displayName, point.2)
                    )
                    .foregroundStyle(strengthColor.opacity(0.7))
                    .symbolSize(100)
                }

                // Add trend line
                if let trendLine = calculateTrendLine() {
                    ForEach(trendLine, id: \.x) { point in
                        LineMark(
                            x: .value(analysis.primaryMetric.displayName, point.x),
                            y: .value(analysis.secondaryMetric.displayName, point.y)
                        )
                        .foregroundStyle(strengthColor)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    }
                }
            }
            .frame(height: 250)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatValueForAxis(doubleValue, for: analysis.primaryMetric))
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatValueForAxis(doubleValue, for: analysis.secondaryMetric))
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: CloveSpacing.large) {
                HStack(spacing: CloveSpacing.small) {
                    Circle()
                        .fill(strengthColor.opacity(0.7))
                        .frame(width: 8, height: 8)
                    Text("Data Points")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }

                HStack(spacing: CloveSpacing.small) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(strengthColor)
                        .frame(width: 16, height: 2)
                    Text("Trend Line")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }

                Spacer()
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

            VStack(spacing: CloveSpacing.medium) {
                // Primary metric chart
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text(analysis.primaryMetric.displayName)
                        .font(CloveFonts.body())
                        .foregroundStyle(Theme.shared.accent)
                        .fontWeight(.semibold)
                    
                    Chart {
                        ForEach(Array(analysis.dataPoints.enumerated()), id: \.offset) { index, point in
                            LineMark(
                                x: .value("Date", point.0),
                                y: .value("Value", point.1)
                            )
                            .foregroundStyle(Theme.shared.accent)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", point.0),
                                y: .value("Value", point.1)
                            )
                            .foregroundStyle(Theme.shared.accent)
                            .symbolSize(25)
                        }
                    }
                    .frame(height: 120)
                    .chartYScale(domain: primaryYAxisDomain)
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                            AxisValueLabel {
                                Text(formatValueForAxis(value.as(Double.self) ?? 0, for: analysis.primaryMetric))
                                    .font(CloveFonts.small())
                                    .foregroundStyle(Theme.shared.accent)
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                    }
                }
                
                // Secondary metric chart
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text(analysis.secondaryMetric.displayName)
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.blue)
                        .fontWeight(.semibold)
                    
                    Chart {
                        ForEach(Array(analysis.dataPoints.enumerated()), id: \.offset) { index, point in
                            LineMark(
                                x: .value("Date", point.0),
                                y: .value("Value", point.2)
                            )
                            .foregroundStyle(CloveColors.blue)
                            .lineStyle(StrokeStyle(lineWidth: 3, dash: [5, 5]))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", point.0),
                                y: .value("Value", point.2)
                            )
                            .foregroundStyle(CloveColors.blue)
                            .symbolSize(25)
                            .symbol(Circle().strokeBorder(lineWidth: 2))
                        }
                    }
                    .frame(height: 120)
                    .chartYScale(domain: secondaryYAxisDomain)
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                            AxisValueLabel {
                                Text(formatValueForAxis(value.as(Double.self) ?? 0, for: analysis.secondaryMetric))
                                    .font(CloveFonts.small())
                                    .foregroundStyle(CloveColors.blue)
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                    }
                }
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
                            .foregroundStyle(Theme.shared.accent)
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
                        .fill(Theme.shared.accent)
                )
            }
            Spacer()
        }
    }

    // MARK: - User-Friendly Display Helpers
    
    private var relationshipIcon: some View {
        let absCoeff = abs(analysis.coefficient)
        let isPositive = analysis.coefficient > 0
        
        if absCoeff < 0.2 {
            return Image(systemName: "questionmark.circle")
                .foregroundStyle(CloveColors.secondaryText)
        } else if absCoeff < 0.4 {
            return Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .foregroundStyle(.orange)
        } else if absCoeff < 0.6 {
            return Image(systemName: isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .foregroundStyle(Theme.shared.accent)
        } else {
            return Image(systemName: isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .foregroundStyle(CloveColors.green)
        }
    }
    
    private var relationshipTitle: String {
        let absCoeff = abs(analysis.coefficient)
        let primary = analysis.primaryMetric.displayName
        let secondary = analysis.secondaryMetric.displayName
        
        if absCoeff < 0.2 {
            return "\(primary) and \(secondary) don't seem related"
        } else if absCoeff < 0.4 {
            return "\(primary) and \(secondary) might be connected"
        } else if absCoeff < 0.6 {
            return "\(primary) and \(secondary) are connected"
        } else {
            return "\(primary) and \(secondary) are closely related"
        }
    }
    
    private var relationshipDescription: String {
        let absCoeff = abs(analysis.coefficient)
        let isPositive = analysis.coefficient > 0
        let primary = analysis.primaryMetric.displayName.lowercased()
        let secondary = analysis.secondaryMetric.displayName.lowercased()
        
        if absCoeff < 0.2 {
            return "No clear pattern found between these metrics."
        } else if isPositive {
            return "When \(primary) increases, \(secondary) tends to increase too."
        } else {
            return "When \(primary) increases, \(secondary) tends to decrease."
        }
    }
    
    private var strengthMeter: some View {
        let absCoeff = abs(analysis.coefficient)
        let maxBars = 5
        let filledBars = max(1, Int(absCoeff * Double(maxBars)))
        
        return HStack(spacing: 2) {
            ForEach(0..<maxBars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < filledBars ? strengthColor : CloveColors.secondaryText.opacity(0.2))
                    .frame(width: 8, height: 16)
            }
        }
    }
    
    private var strengthDescription: String {
        let absCoeff = abs(analysis.coefficient)
        switch absCoeff {
        case 0.8...1.0: return "Very Strong"
        case 0.6..<0.8: return "Strong"
        case 0.4..<0.6: return "Moderate"
        case 0.2..<0.4: return "Weak"
        default: return "Very Weak"
        }
    }
    
    private var strengthColor: Color {
        let absCoeff = abs(analysis.coefficient)
        switch absCoeff {
        case 0.6...: return CloveColors.green
        case 0.4..<0.6: return Theme.shared.accent
        case 0.2..<0.4: return .orange
        default: return CloveColors.secondaryText
        }
    }

    // MARK: - Chart Helpers

    private func calculateTrendLine() -> [(x: Double, y: Double)]? {
        let xValues = analysis.dataPoints.map { $0.1 }
        let yValues = analysis.dataPoints.map { $0.2 }

        guard let xMin = xValues.min(),
              let xMax = xValues.max(),
              xMax != xMin else {
            return nil
        }

        let n = Double(analysis.dataPoints.count)
        let xSum = xValues.reduce(0, +)
        let ySum = yValues.reduce(0, +)
        let xMean = xSum / n
        let yMean = ySum / n

        let numerator = zip(xValues, yValues).map { (x, y) in
            (x - xMean) * (y - yMean)
        }.reduce(0, +)

        let denominator = xValues.map { pow($0 - xMean, 2) }.reduce(0, +)

        guard denominator != 0 else { return nil }

        let slope = numerator / denominator
        let intercept = yMean - slope * xMean

        // Calculate trend line points at min and max x values
        let yAtMin = slope * xMin + intercept
        let yAtMax = slope * xMax + intercept

        return [
            (x: xMin, y: yAtMin),
            (x: xMax, y: yAtMax)
        ]
    }

    private var primaryYAxisDomain: ClosedRange<Double> {
        let primaryValues = analysis.dataPoints.map { $0.1 }
        guard let min = primaryValues.min(), let max = primaryValues.max() else {
            return 0...10
        }
        let padding = (max - min) * 0.1
        return (min - padding)...(max + padding)
    }
    
    private var secondaryYAxisDomain: ClosedRange<Double> {
        let secondaryValues = analysis.dataPoints.map { $0.2 }
        guard let min = secondaryValues.min(), let max = secondaryValues.max() else {
            return 0...10
        }
        let padding = (max - min) * 0.1
        return (min - padding)...(max + padding)
    }
    
    private func formatValueForAxis(_ value: Double, for metric: any MetricProvider) -> String {
        // Use the MetricProvider's built-in formatValue method
        return metric.formatValue(value)
    }
    
    private func convertNumericToWeather(_ numericValue: Double) -> String {
        switch numericValue {
        case 1.0: return "Stormy"
        case 2.0: return "Rainy"
        case 3.0: return "Gloomy"
        case 4.0: return "Cloudy"
        case 5.0: return "Snow"
        case 6.0: return "Sunny"
        default: return "Mixed"
        }
    }

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
            return Theme.shared.accent
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

// MARK: - Statistical Tooltip View

struct StatisticalTooltipView: View {
    let term: StatisticalTerm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            // Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.shared.accent)

                Text(term.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Explanation
            Text(term.explanation)
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            // Examples based on term
            if term == .correlationCoefficient {
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    exampleRow(value: "0.8 to 1.0", meaning: "Very strong positive relationship")
                    exampleRow(value: "0.0 to 0.2", meaning: "Little to no relationship")
                    exampleRow(value: "-0.8 to -1.0", meaning: "Very strong negative relationship")
                }
                .padding(CloveSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.small)
                        .fill(Theme.shared.accent.opacity(0.1))
                )
            }

            Spacer()
        }
        .padding(CloveSpacing.large)
        .background(CloveColors.background)
    }

    private func exampleRow(value: String, meaning: String) -> some View {
        HStack(spacing: CloveSpacing.small) {
            Text(value)
                .font(CloveFonts.small())
                .foregroundStyle(Theme.shared.accent)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(CloveColors.secondaryText)

            Text(meaning)
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
        }
    }
}

