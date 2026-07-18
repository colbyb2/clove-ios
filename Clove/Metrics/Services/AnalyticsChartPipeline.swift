import Foundation

enum AnalyticsChartFamily: Equatable, Sendable {
    case numericLine
    case countBars
    case binaryRate
    case categoricalDistribution
    case eventOccurrences
    case hydrationProgress(goal: Double)
    case bristolDistribution
}

enum AnalyticsChartDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case raw = "Daily"
    case rolling = "7-day"

    var id: String { rawValue }
}

struct AnalyticsChartPoint: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let value: Double
    let denominator: Int?
    let segment: Int
    let category: String?
    let isPreviousPeriod: Bool
}

struct AnalyticsCategoryPoint: Identifiable, Equatable, Sendable {
    var id: String { "\(category)|\(isPreviousPeriod)" }
    let category: String
    let count: Int
    let isPreviousPeriod: Bool
}

struct AnalyticsChartResult: Equatable, Sendable {
    let definition: MetricDefinition
    let interval: DateInterval
    let family: AnalyticsChartFamily
    let granularity: AnalyticsGranularity
    let points: [AnalyticsChartPoint]
    let rollingPoints: [AnalyticsChartPoint]
    let previousPoints: [AnalyticsChartPoint]
    let categories: [AnalyticsCategoryPoint]
    let rawEvents: [MetricRawEvent]
    let summary: MetricAnalysisSummary
    let aggregationLabel: String
}

struct AnalyticsDateRangeFactory {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func interval(for period: TimePeriod, now: Date = Date()) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        guard period != .allTime else {
            return DateInterval(start: Date(timeIntervalSince1970: 0), end: end)
        }
        let start = calendar.date(byAdding: .day, value: -(period.days - 1), to: today)!
        return DateInterval(start: start, end: end)
    }

    func custom(start: Date, inclusiveEnd: Date) -> DateInterval? {
        let lower = calendar.startOfDay(for: start)
        guard let upper = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: inclusiveEnd)), lower < upper else { return nil }
        return DateInterval(start: lower, end: upper)
    }

    func previous(equalTo interval: DateInterval) -> DateInterval? {
        let startDay = calendar.startOfDay(for: interval.start)
        let lastIncluded = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.start
        let endDay = calendar.startOfDay(for: lastIncluded)
        guard let dayCount = calendar.dateComponents([.day], from: startDay, to: endDay).day.map({ $0 + 1 }), dayCount > 0,
              let previousStart = calendar.date(byAdding: .day, value: -dayCount, to: startDay) else { return nil }
        return DateInterval(start: previousStart, end: startDay)
    }
}

struct AnalyticsChartPipeline {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func build(
        definition: MetricDefinition,
        dataset: AnalyticsDataset,
        previousDataset: AnalyticsDataset? = nil,
        granularity: AnalyticsGranularity
    ) -> AnalyticsChartResult {
        let summary = MetricAnalysisSummaryEngine().summarize(
            definition: definition,
            dataset: dataset,
            previousDataset: previousDataset
        )
        let family = chartFamily(for: definition)
        let current = points(for: definition, dataset: dataset, granularity: granularity, previous: false)
        let previous = previousDataset.map { points(for: definition, dataset: $0, granularity: granularity, previous: true) } ?? []
        let categories = categoryPoints(for: definition, dataset: dataset, previous: false)
            + (previousDataset.map { categoryPoints(for: definition, dataset: $0, previous: true) } ?? [])
        return AnalyticsChartResult(
            definition: definition,
            interval: dataset.interval,
            family: family,
            granularity: granularity,
            points: current,
            rollingPoints: rollingAverage(current),
            previousPoints: previous,
            categories: categories,
            rawEvents: dataset.rawEvents.filter { $0.metricID == definition.id },
            summary: summary,
            aggregationLabel: aggregationLabel(for: definition, granularity: granularity)
        )
    }

    func granularity(for interval: DateInterval) -> AnalyticsGranularity {
        let start = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        if days <= 31 { return .daily }
        if days <= 180 { return .weekly }
        return .monthly
    }

    private func chartFamily(for definition: MetricDefinition) -> AnalyticsChartFamily {
        if definition.id == MetricCatalog.hydration.id { return .hydrationProgress(goal: 64) }
        if definition.id == MetricCatalog.bristolStoolType.id { return .bristolDistribution }
        switch definition.measurementLevel {
        case .categorical:
            return .categoricalDistribution
        case .ordinal where definition.aggregation.daily == .distribution:
            return .categoricalDistribution
        case .binary, .percentage:
            return .binaryRate
        case .count:
            return .countBars
        case .event:
            return .eventOccurrences
        default:
            return .numericLine
        }
    }

    private func points(
        for definition: MetricDefinition,
        dataset: AnalyticsDataset,
        granularity: AnalyticsGranularity,
        previous: Bool
    ) -> [AnalyticsChartPoint] {
        let values = dataset.observations(for: definition.id).compactMap { observation -> (Date, MetricObservedValue)? in
            guard case .observed(let value) = observation.state else { return nil }
            return (observation.day, value)
        }
        let grouped = Dictionary(grouping: values) { bucketStart(for: $0.0, granularity: granularity) }
        var segment = 0
        var lastDate: Date?
        return grouped.keys.sorted().compactMap { date in
            let bucket = grouped[date] ?? []
            guard let aggregate = aggregate(bucket.map(\.1), definition: definition, granularity: granularity) else { return nil }
            if let lastDate, granularity == .daily,
               let expected = calendar.date(byAdding: .day, value: 1, to: lastDate), !calendar.isDate(expected, inSameDayAs: date) {
                segment += 1
            }
            lastDate = date
            return AnalyticsChartPoint(
                id: "\(definition.id.rawValue)|\(date.timeIntervalSinceReferenceDate)|\(previous)",
                date: date,
                value: aggregate.value,
                denominator: aggregate.denominator,
                segment: segment,
                category: nil,
                isPreviousPeriod: previous
            )
        }
    }

    private func aggregate(
        _ values: [MetricObservedValue],
        definition: MetricDefinition,
        granularity: AnalyticsGranularity
    ) -> (value: Double, denominator: Int?)? {
        if definition.measurementLevel == .percentage {
            let ratios = values.compactMap { value -> (Int, Int)? in
                if case .ratio(let numerator, let denominator) = value, denominator > 0 { return (numerator, denominator) }
                return nil
            }
            if !ratios.isEmpty {
                let n = ratios.reduce(0) { $0 + $1.0 }
                let d = ratios.reduce(0) { $0 + $1.1 }
                return (Double(n) / Double(d) * 100, d)
            }
        }
        let numeric = values.compactMap(\.numericValue)
        guard !numeric.isEmpty else { return nil }
        if definition.measurementLevel == .binary {
            return (numeric.reduce(0, +) / Double(numeric.count) * 100, numeric.count)
        }
        let reducer: MetricAggregationReducer = switch granularity {
        case .daily: definition.aggregation.daily
        case .weekly: definition.aggregation.weekly
        case .monthly: definition.aggregation.monthly
        }
        switch reducer {
        case .sum, .count: return (numeric.reduce(0, +), numeric.count)
        case .median:
            let sorted = numeric.sorted()
            let value = sorted.count.isMultiple(of: 2) ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2 : sorted[sorted.count / 2]
            return (value, sorted.count)
        case .latest: return (numeric.last!, numeric.count)
        default: return (numeric.reduce(0, +) / Double(numeric.count), numeric.count)
        }
    }

    private func categoryPoints(
        for definition: MetricDefinition,
        dataset: AnalyticsDataset,
        previous: Bool
    ) -> [AnalyticsCategoryPoint] {
        guard definition.measurementLevel == .categorical || definition.aggregation.daily == .distribution else { return [] }
        var counts: [String: Int] = [:]
        for observation in dataset.observations(for: definition.id) {
            guard case .observed(let value) = observation.state else { continue }
            switch value {
            case .category(let category): counts[displayCategory(category, definition: definition), default: 0] += 1
            case .distribution(let buckets):
                for bucket in buckets { counts[displayCategory(bucket.value, definition: definition), default: 0] += bucket.count }
            case .number(let number): counts[displayCategory("number:\(number)", definition: definition), default: 0] += 1
            default: break
            }
        }
        return counts.keys.sorted().map { AnalyticsCategoryPoint(category: $0, count: counts[$0]!, isPreviousPeriod: previous) }
    }

    private func displayCategory(_ rawValue: String, definition: MetricDefinition) -> String {
        let value = rawValue
            .replacingOccurrences(of: "category:", with: "")
            .replacingOccurrences(of: "number:", with: "")
        guard definition.id == MetricCatalog.bristolStoolType.id, let number = Double(value) else { return value }
        return "Type \(Int(number))"
    }

    private func bucketStart(for date: Date, granularity: AnalyticsGranularity) -> Date {
        switch granularity {
        case .daily: return calendar.startOfDay(for: date)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .monthly:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    private func rollingAverage(_ points: [AnalyticsChartPoint]) -> [AnalyticsChartPoint] {
        guard points.count > 1 else { return points }
        return points.indices.map { index in
            let lower = max(0, index - 6)
            let window = points[lower...index]
            return AnalyticsChartPoint(
                id: points[index].id + "|rolling",
                date: points[index].date,
                value: window.map(\.value).reduce(0, +) / Double(window.count),
                denominator: window.compactMap(\.denominator).reduce(0, +),
                segment: points[index].segment,
                category: points[index].category,
                isPreviousPeriod: false
            )
        }
    }

    private func aggregationLabel(for definition: MetricDefinition, granularity: AnalyticsGranularity) -> String {
        let reducer: MetricAggregationReducer = switch granularity {
        case .daily: definition.aggregation.daily
        case .weekly: definition.aggregation.weekly
        case .monthly: definition.aggregation.monthly
        }
        return "\(granularity.rawValue.capitalized) · \(reducer.rawValue.replacingOccurrences(of: "weightedPercentage", with: "weighted rate").replacingOccurrences(of: "occurrenceRate", with: "occurrence rate"))"
    }
}
