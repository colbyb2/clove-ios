import Foundation

extension CustomMetricDefinition {
    var analyticsDefinition: MetricDefinition {
        let level: MetricMeasurementLevel = switch kind { case .yesNo: .binary; case .count: .count; case .rating: .ordinal; default: .continuous }
        let domain: MetricValueDomain = switch kind {
        case .yesNo: .numeric(0...1)
        case .count, .duration: .nonNegative
        case .rating: .numeric(Double(ratingMin)...Double(ratingMax))
        case .number: .unrestricted
        }
        let metricUnit: MetricUnit = switch kind {
        case .yesNo: .occurrence
        case .rating: .score
        case .duration: .minutes
        case .count: unit.isEmpty ? .count : .custom(symbol: unit)
        case .number: .custom(symbol: unit.isEmpty ? "value" : unit)
        }
        return MetricDefinition(id: metricID, displayName: name, description: "Your daily \(name) records", category: .customMetrics,
            source: .customDailyValues, measurementLevel: level, unit: metricUnit, domain: domain, directionality: .neutral,
            aggregation: MetricAggregationPolicy(daily: .latest, weekly: kind == .yesNo ? .occurrenceRate : .average,
                                                 monthly: kind == .yesNo ? .occurrenceRate : .average),
            unrecordedDayPolicy: .missing,
            supportedAnalyses: [.descriptive, .trend, .distribution, .periodComparison, .relationship, .laggedRelationship],
            recommendedVisualizations: kind == .yesNo ? [.bar, .occurrenceStrip] : [.line, .bar],
            displayFormat: MetricDisplayFormat(maximumFractionDigits: precision))
    }
}

struct CustomMetricProvider: MetricProvider {
    let definition: CustomMetricDefinition
    var id: String { definition.metricID.rawValue }
    var displayName: String { definition.name }
    var description: String { definition.analyticsDefinition.description }
    var icon: String { definition.icon }
    var category: MetricCategory { .customMetrics }
    var dataType: MetricDataType {
        switch definition.kind {
        case .yesNo: .binary
        case .count: .count
        case .rating: .continuous(range: Double(definition.ratingMin)...Double(definition.ratingMax))
        default: .custom
        }
    }
    var chartType: MetricChartType { definition.kind == .count || definition.kind == .yesNo ? .bar : .line }
    var valueRange: ClosedRange<Double>? { definition.kind == .rating ? Double(definition.ratingMin)...Double(definition.ratingMax) : nil }
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let interval = AnalyticsDateRangeFactory().interval(for: period)
        guard let dataset = try? await AnalyticsRepositoryContainer.shared.load(AnalyticsRequest(interval: interval, metricIDs: [definition.metricID])) else { return [] }
        return dataset.observations(for: definition.metricID).compactMap { item in
            guard case .observed(let value) = item.state, let number = value.numericValue else { return nil }
            return MetricDataPoint(date: item.day, value: number, metricId: id)
        }
    }
    func getDataPointCount(for period: TimePeriod) async -> Int { await getDataPoints(for: period).count }
    func formatValue(_ value: Double) -> String {
        switch definition.kind {
        case .yesNo: return value == 0 ? "No" : "Yes"
        case .duration:
            let minutes = max(0, Int(value.rounded()))
            return "\(minutes / 60)h \(minutes % 60)m"
        case .rating: return value.formatted(.number.precision(.fractionLength(0)))
        default:
            let number = value.formatted(.number.precision(.fractionLength(0...definition.precision)))
            return definition.unit.isEmpty ? number : "\(number) \(definition.unit)"
        }
    }
}
