import SwiftUI

/// Presentation decisions derived from metric semantics rather than individual screens.
/// Analytics calculations remain owned by `MetricAnalysisSummaryEngine` and
/// `AnalyticsChartPipeline`; this type only controls how those results are explained.
enum MetricPresentation {
    struct Narrative: Equatable {
        let headline: String
        let detail: String
    }

    static func tint(for definition: MetricDefinition) -> Color {
        if definition.id == MetricCatalog.mood.id { return Theme.shared.accent }
        if definition.id == MetricCatalog.painLevel.id { return CloveColors.orange }
        if definition.id == MetricCatalog.energyLevel.id { return CloveColors.yellow }
        if definition.id == MetricCatalog.hydration.id { return CloveColors.blue }
        if definition.id == MetricCatalog.bristolStoolType.id ||
            definition.id == MetricCatalog.bowelMovementFrequency.id { return .indigo }
        if definition.id == MetricCatalog.medicationAdherence.id { return .teal }
        if definition.id == MetricCatalog.flowLevel.id { return CloveColors.red }
        return tint(for: definition.category)
    }

    static func tint(for category: MetricSemanticCategory) -> Color {
        switch category {
        case .coreHealth: Theme.shared.accent
        case .symptoms: CloveColors.orange
        case .medications: .teal
        case .lifestyle: .indigo
        case .environmental: .cyan
        case .activities: CloveColors.green
        case .meals: CloveColors.yellow
        }
    }

    static func tint(for category: MetricCategory) -> Color {
        switch category {
        case .coreHealth: Theme.shared.accent
        case .symptoms: CloveColors.orange
        case .medications: .teal
        case .lifestyle: .indigo
        case .environmental: .cyan
        case .activities: CloveColors.green
        case .meals: CloveColors.yellow
        }
    }

    static func statusColor(for favorability: MetricChangeFavorability) -> Color {
        switch favorability {
        case .favorable: CloveColors.success
        case .unfavorable: CloveColors.orange
        case .neutral: CloveColors.secondaryText
        }
    }

    static func valueColor(_ value: Double, definition: MetricDefinition) -> Color {
        guard case .numeric(let range) = definition.domain,
              range.upperBound > range.lowerBound,
              definition.directionality != .neutral else {
            return tint(for: definition)
        }
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        var progress = (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
        if definition.directionality == .lowerIsBetter { progress = 1 - progress }
        switch progress {
        case 0..<0.25: return CloveColors.red
        case 0.25..<0.5: return CloveColors.orange
        case 0.5..<0.75: return CloveColors.yellow
        default: return CloveColors.success
        }
    }

    static func chartTitle(for family: AnalyticsChartFamily) -> String {
        switch family {
        case .categoricalDistribution, .bristolDistribution: "Distribution"
        case .eventOccurrences: "Recorded dates"
        default: "Over time"
        }
    }

    static func narrative(
        definition: MetricDefinition,
        summary: MetricAnalysisSummary,
        format: (Double) -> String
    ) -> Narrative? {
        guard let value = summary.value else { return nil }
        let headline: String
        switch value {
        case .numeric(let mean, _, _, _, let total):
            headline = total.map { "\(format($0)) recorded" }
                ?? "\(definition.displayName) averaged \(format(mean))"
        case .binary(let occurrences, let denominator, _):
            headline = "Recorded on \(occurrences) of \(denominator) observed days"
        case .categorical(_, let mode):
            headline = mode.map { "\($0) was most common" } ?? "A distribution is available"
        case .event(let occurrences, let activeDays):
            headline = occurrences == activeDays
                ? "Recorded on \(activeDays) \(dayWord(activeDays))"
                : "\(occurrences) occurrences across \(activeDays) \(dayWord(activeDays))"
        case .percentage(let percentage, let numerator, let denominator):
            if definition.id == MetricCatalog.medicationAdherence.id,
               let numerator, let denominator {
                headline = "\(numerator) of \(denominator) eligible doses recorded as taken"
            } else {
                headline = "\(Int(percentage.rounded()))% recorded"
            }
        }

        let detail: String
        if definition.measurementLevel == .event {
            detail = definition.category == .medications
                ? "Unrecorded days are not treated as missed doses."
                : "Only explicitly recorded occurrences are shown."
        } else if let trend = summary.trend {
            detail = trendDescription(trend, definition: definition)
        } else {
            let days = summary.coverage.sourceDayCount
            detail = "Based on \(days) recorded \(dayWord(days)) in this period."
        }
        return Narrative(headline: headline, detail: detail)
    }

    static func trendDescription(_ trend: MetricTrendSummary, definition: MetricDefinition) -> String {
        if trend.direction == .stable { return "The recorded values were generally steady." }
        let direction = trend.direction == .increasing ? "increased" : "decreased"
        switch trend.favorability {
        case .favorable: return "The recorded values \(direction) in a favorable direction."
        case .unfavorable: return "The recorded values \(direction) and may deserve attention."
        case .neutral: return "The recorded values \(direction) during this period."
        }
    }

    private static func dayWord(_ count: Int) -> String {
        count == 1 ? "day" : "days"
    }
}
