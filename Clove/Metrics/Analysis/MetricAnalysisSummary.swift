import Foundation

enum MetricSummaryValue: Equatable, Sendable {
    case numeric(mean: Double, median: Double, minimum: Double, maximum: Double, total: Double?)
    case binary(occurrences: Int, denominator: Int, rate: Double)
    case categorical(buckets: [MetricDistributionBucket], mode: String?)
    case event(occurrences: Int, activeDays: Int)
    case percentage(value: Double, numerator: Int?, denominator: Int?)

    var comparisonScalar: Double? {
        switch self {
        case .numeric(let mean, _, _, _, _): mean
        case .binary(_, _, let rate): rate
        case .event(let occurrences, _): Double(occurrences)
        case .percentage(let value, _, _): value
        case .categorical: nil
        }
    }
}

struct MetricTrendSummary: Equatable, Sendable {
    let direction: MetricChangeDirection
    let favorability: MetricChangeFavorability
    let absoluteChange: Double
    let sampleCount: Int
}

struct MetricPeriodComparison: Equatable, Sendable {
    let current: MetricSummaryValue
    let previous: MetricSummaryValue
    let direction: MetricChangeDirection?
    let favorability: MetricChangeFavorability
    let absoluteChange: Double?
    let currentCoverage: MetricCoverage
    let previousCoverage: MetricCoverage
}

struct MetricNotableDate: Identifiable, Equatable, Sendable {
    var id: String { "\(date.timeIntervalSinceReferenceDate)|\(value)" }
    let date: Date
    let value: Double
}

struct MetricAnalysisSummary: Equatable, Sendable {
    let metricID: MetricID
    let interval: DateInterval
    let value: MetricSummaryValue?
    let latestObservation: MetricObservation?
    let coverage: MetricCoverage
    let trend: MetricTrendSummary?
    let comparison: MetricPeriodComparison?
    let notableDates: [MetricNotableDate]
    let limitations: [String]
}

struct MetricAnalysisSummaryEngine {
    func summarize(
        definition: MetricDefinition,
        dataset: AnalyticsDataset,
        previousDataset: AnalyticsDataset? = nil
    ) -> MetricAnalysisSummary {
        let observations = dataset.observations(for: definition.id)
        let coverage = dataset.coverage[definition.id] ?? emptyCoverage(for: definition.id, interval: dataset.interval)
        let value = summarizeValue(definition: definition, observations: observations, rawEvents: dataset.rawEvents)
        let numeric = numericObservations(observations)
        let trend = trendSummary(definition: definition, values: numeric)
        let previousValue = previousDataset.flatMap {
            summarizeValue(definition: definition, observations: $0.observations(for: definition.id), rawEvents: $0.rawEvents)
        }
        let previousCoverage = previousDataset.flatMap { $0.coverage[definition.id] }
        let comparison = makeComparison(
            definition: definition,
            current: value,
            previous: previousValue,
            currentCoverage: coverage,
            previousCoverage: previousCoverage
        )

        return MetricAnalysisSummary(
            metricID: definition.id,
            interval: dataset.interval,
            value: value,
            latestObservation: observations.last(where: { if case .observed = $0.state { true } else { false } }),
            coverage: coverage,
            trend: trend,
            comparison: comparison,
            notableDates: notableDates(from: numeric, directionality: definition.directionality),
            limitations: limitations(
                definition: definition,
                coverage: coverage,
                numericCount: numeric.count,
                hasValue: value != nil,
                comparison: comparison,
                requestedComparison: previousDataset != nil
            )
        )
    }

    private func summarizeValue(
        definition: MetricDefinition,
        observations: [MetricObservation],
        rawEvents: [MetricRawEvent]
    ) -> MetricSummaryValue? {
        if definition.measurementLevel == .categorical || definition.aggregation.daily == .distribution {
            let buckets = categoricalBuckets(observations, definition: definition)
            guard !buckets.isEmpty else { return nil }
            return .categorical(buckets: buckets, mode: buckets.max { lhs, rhs in
                lhs.count == rhs.count ? lhs.value > rhs.value : lhs.count < rhs.count
            }?.value)
        }
        switch definition.measurementLevel {
        case .binary:
            let values = observations.compactMap { observation -> Bool? in
                guard case .observed(let value) = observation.state else { return nil }
                switch value {
                case .boolean(let flag): return flag
                case .number(let number): return number != 0
                default: return nil
                }
            }
            guard !values.isEmpty else { return nil }
            let occurrences = values.filter { $0 }.count
            return .binary(occurrences: occurrences, denominator: values.count, rate: Double(occurrences) / Double(values.count) * 100)

        case .categorical:
            return nil // Handled as a distribution above.

        case .event:
            let matchingEvents = rawEvents.filter { $0.metricID == definition.id }
            let numericCounts = numericObservations(observations)
            let occurrences = !matchingEvents.isEmpty
                ? matchingEvents.count
                : Int(numericCounts.reduce(0) { $0 + $1.value })
            guard occurrences > 0 else { return nil }
            return .event(occurrences: occurrences, activeDays: Set((!matchingEvents.isEmpty ? matchingEvents.map(\.day) : numericCounts.map(\.date))).count)

        case .percentage:
            var numerator = 0
            var denominator = 0
            var fallback: [Double] = []
            for observation in observations {
                guard case .observed(let value) = observation.state else { continue }
                switch value {
                case .ratio(let n, let d) where d > 0:
                    numerator += n
                    denominator += d
                default:
                    if let number = value.numericValue { fallback.append(number) }
                }
            }
            if denominator > 0 {
                return .percentage(value: Double(numerator) / Double(denominator) * 100, numerator: numerator, denominator: denominator)
            }
            guard !fallback.isEmpty else { return nil }
            return .percentage(value: fallback.reduce(0, +) / Double(fallback.count), numerator: nil, denominator: nil)

        case .continuous, .ordinal, .count, .custom:
            let values = numericObservations(observations).map(\.value)
            guard !values.isEmpty else { return nil }
            let sorted = values.sorted()
            let median = sorted.count.isMultiple(of: 2)
                ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
                : sorted[sorted.count / 2]
            return .numeric(
                mean: values.reduce(0, +) / Double(values.count),
                median: median,
                minimum: sorted[0],
                maximum: sorted[sorted.count - 1],
                total: definition.measurementLevel == .count ? values.reduce(0, +) : nil
            )
        }
    }

    private func categoricalBuckets(
        _ observations: [MetricObservation],
        definition: MetricDefinition
    ) -> [MetricDistributionBucket] {
        var counts: [String: Int] = [:]
        for observation in observations {
            guard case .observed(let value) = observation.state else { continue }
            switch value {
            case .category(let category): counts[displayBucket(category, definition: definition), default: 0] += 1
            case .distribution(let buckets):
                for bucket in buckets { counts[displayBucket(bucket.value, definition: definition), default: 0] += bucket.count }
            case .number(let number): counts[displayBucket("number:\(number)", definition: definition), default: 0] += 1
            default: break
            }
        }
        return counts.map { MetricDistributionBucket(value: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.value < $1.value : $0.count > $1.count }
    }

    private func displayBucket(_ rawValue: String, definition: MetricDefinition) -> String {
        let value = rawValue
            .replacingOccurrences(of: "category:", with: "")
            .replacingOccurrences(of: "number:", with: "")
        guard definition.id == MetricCatalog.bristolStoolType.id, let number = Double(value) else { return value }
        return "Type \(Int(number))"
    }

    private func numericObservations(_ observations: [MetricObservation]) -> [(date: Date, value: Double)] {
        observations.compactMap { observation in
            guard case .observed(let observed) = observation.state, let value = observed.numericValue else { return nil }
            return (observation.day, value)
        }.sorted { $0.date < $1.date }
    }

    private func trendSummary(
        definition: MetricDefinition,
        values: [(date: Date, value: Double)]
    ) -> MetricTrendSummary? {
        guard definition.supportedAnalyses.contains(.trend), values.count >= definition.minimumSamples.trend else { return nil }
        let midpoint = values.count / 2
        guard midpoint > 0 else { return nil }
        let first = values.prefix(midpoint).map(\.value)
        let second = values.suffix(values.count - midpoint).map(\.value)
        let firstMean = first.reduce(0, +) / Double(first.count)
        let secondMean = second.reduce(0, +) / Double(second.count)
        let change = secondMean - firstMean
        let observedRange = (values.map(\.value).max() ?? 0) - (values.map(\.value).min() ?? 0)
        let threshold = max(observedRange * 0.05, 0.01)
        let direction: MetricChangeDirection = change > threshold ? .increasing : (change < -threshold ? .decreasing : .stable)
        return MetricTrendSummary(
            direction: direction,
            favorability: definition.directionality.favorability(of: direction),
            absoluteChange: change,
            sampleCount: values.count
        )
    }

    private func makeComparison(
        definition: MetricDefinition,
        current: MetricSummaryValue?,
        previous: MetricSummaryValue?,
        currentCoverage: MetricCoverage,
        previousCoverage: MetricCoverage?
    ) -> MetricPeriodComparison? {
        guard let current, let previous, let previousCoverage else { return nil }
        guard let currentScalar = current.comparisonScalar, let previousScalar = previous.comparisonScalar else {
            return MetricPeriodComparison(
                current: current,
                previous: previous,
                direction: nil,
                favorability: .neutral,
                absoluteChange: nil,
                currentCoverage: currentCoverage,
                previousCoverage: previousCoverage
            )
        }
        let change = currentScalar - previousScalar
        let direction: MetricChangeDirection = abs(change) < 0.000_001 ? .stable : (change > 0 ? .increasing : .decreasing)
        return MetricPeriodComparison(
            current: current,
            previous: previous,
            direction: direction,
            favorability: definition.directionality.favorability(of: direction),
            absoluteChange: change,
            currentCoverage: currentCoverage,
            previousCoverage: previousCoverage
        )
    }

    private func notableDates(
        from values: [(date: Date, value: Double)],
        directionality: MetricDirectionality
    ) -> [MetricNotableDate] {
        let sorted: [(date: Date, value: Double)]
        switch directionality {
        case .lowerIsBetter: sorted = values.sorted { $0.value > $1.value }
        case .higherIsBetter: sorted = values.sorted { $0.value < $1.value }
        case .neutral: sorted = values.sorted { $0.value > $1.value }
        }
        return sorted.prefix(3).map { MetricNotableDate(date: $0.date, value: $0.value) }
    }

    private func limitations(
        definition: MetricDefinition,
        coverage: MetricCoverage,
        numericCount: Int,
        hasValue: Bool,
        comparison: MetricPeriodComparison?,
        requestedComparison: Bool
    ) -> [String] {
        var result: [String] = []
        if !hasValue { result.append("No observed values were recorded in this range.") }
        if coverage.observedDayFraction < 0.5 {
            result.append("Fewer than half of the days in this range have source data.")
        }
        if definition.supportedAnalyses.contains(.trend), numericCount < definition.minimumSamples.trend {
            result.append("At least \(definition.minimumSamples.trend) observations are needed to estimate a trend.")
        }
        if requestedComparison, comparison == nil {
            result.append("The previous period does not contain enough comparable data.")
        }
        if definition.measurementLevel == .event {
            result.append("Unrecorded days are not assumed to mean the event did not occur.")
        }
        return result
    }

    private func emptyCoverage(for id: MetricID, interval: DateInterval) -> MetricCoverage {
        MetricCoverage(metricID: id, interval: interval, possibleDayCount: 0, sourceDayCount: 0, observedCount: 0, missingCount: 0, explicitNoneCount: 0, notApplicableCount: 0, firstObservation: nil, lastObservation: nil)
    }
}
