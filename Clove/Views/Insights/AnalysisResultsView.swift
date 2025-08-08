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
                            Text("Correlation Coefficient")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                            Text(String(format: "%.3f", analysis.coefficient))
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(correlationColor(analysis.coefficient))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: CloveSpacing.xsmall) {
                            Text("P-Value")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                            Text(String(format: "%.3f", analysis.pValue))
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(analysis.isSignificant ? CloveColors.green : CloveColors.secondaryText)
                        }
                    }
                    
                    if analysis.isSignificant {
                        HStack(spacing: CloveSpacing.small) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(CloveColors.green)
                            Text("This relationship is statistically significant")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                    } else {
                        HStack(spacing: CloveSpacing.small) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(CloveColors.secondaryText)
                            Text("This relationship may be due to chance")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
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

    // MARK: - Chart

    private var dualAxisChartView: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("Dual Metric Chart")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)

            VStack(spacing: CloveSpacing.medium) {
                // Primary metric chart
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text(analysis.primaryMetric.name)
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
                    Text(analysis.secondaryMetric.name)
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
        let primary = analysis.primaryMetric.name
        let secondary = analysis.secondaryMetric.name
        
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
        let primary = analysis.primaryMetric.name.lowercased()
        let secondary = analysis.secondaryMetric.name.lowercased()
        
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
    
    private func formatValueForAxis(_ value: Double, for metric: SelectableMetric) -> String {
        if let metricType = metric.type {
            switch metricType {
            case .mood, .painLevel, .energyLevel:
                return String(format: "%.1f", value)
            case .medicationAdherence:
                return String(format: "%.0f%%", value)
            case .weather:
                return convertNumericToWeather(value)
            case .flareDay:
                return value == 1.0 ? "Yes" : "No"
            case .activityCount, .mealCount:
                return String(format: "%.0f", value)
            case .medication:
                return value == 1.0 ? "Taken" : "Not taken"
            case .activity:
                return value == 1.0 ? "Done" : "Not done"
            case .meal:
                return value == 1.0 ? "Eaten" : "Not eaten"
            }
        } else if metric.symptomName != nil {
            // Symptom metric
            return String(format: "%.1f", value)
        } else if metric.medicationName != nil {
            // Medication metric
            return value == 1.0 ? "Taken" : "Not taken"
        } else if metric.activityName != nil {
            // Activity metric
            return value == 1.0 ? "Done" : "Not done"
        } else if metric.mealName != nil {
            // Meal metric
            return value == 1.0 ? "Eaten" : "Not eaten"
        } else {
            return String(format: "%.1f", value)
        }
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

