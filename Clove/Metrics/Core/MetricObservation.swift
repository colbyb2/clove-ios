import Foundation

// MARK: - Canonical observation contract

struct MetricObservationID: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

enum MetricSourceKind: String, Sendable {
    case dailyLog
    case symptomRating
    case medicationAdherence
    case medicationOccurrence
    case foodEntry
    case activityEntry
    case bowelMovement
    case cycleEntry
    case dailyReduction
}

/// Stable reference back to the persistence record and field that produced an observation.
struct MetricSourceReference: Hashable, Sendable {
    let kind: MetricSourceKind
    let recordID: String
    let field: String?

    init(kind: MetricSourceKind, recordID: String, field: String? = nil) {
        self.kind = kind
        self.recordID = recordID
        self.field = field
    }

    var stableKey: String {
        [kind.rawValue, recordID, field ?? ""].joined(separator: ":")
    }
}

struct MetricDistributionBucket: Equatable, Sendable {
    let value: String
    let count: Int
}

enum MetricObservedValue: Equatable, Sendable {
    case number(Double)
    case boolean(Bool)
    case category(String)
    case ratio(numerator: Int, denominator: Int)
    case distribution([MetricDistributionBucket])

    var numericValue: Double? {
        switch self {
        case .number(let value):
            return value
        case .boolean(let value):
            return value ? 1 : 0
        case .ratio(let numerator, let denominator):
            guard denominator > 0 else { return nil }
            return Double(numerator) / Double(denominator) * 100
        case .category, .distribution:
            return nil
        }
    }

    fileprivate var bucketKey: String {
        switch self {
        case .number(let value): return "number:\(value)"
        case .boolean(let value): return "boolean:\(value)"
        case .category(let value): return "category:\(value)"
        case .ratio(let numerator, let denominator): return "ratio:\(numerator)/\(denominator)"
        case .distribution(let buckets):
            return "distribution:" + buckets.map { "\($0.value)=\($0.count)" }.joined(separator: ",")
        }
    }
}

enum MetricObservationState: Equatable, Sendable {
    case observed(MetricObservedValue)
    case explicitNone
    case missing
    case notApplicable
}

enum MetricQualityFlag: String, Hashable, Sendable {
    case normalizedBinary
    case normalizedCategory
    case unknownCategory
    case invalidSourceValue
    case ambiguousAbsence
    case unstableSourceIdentity
    case dailyReduction
}

struct MetricObservation: Identifiable, Equatable, Sendable {
    let id: MetricObservationID
    let metricID: MetricID
    let timestamp: Date
    let day: Date
    let state: MetricObservationState
    let source: MetricSourceReference
    let qualityFlags: Set<MetricQualityFlag>

    init(
        metricID: MetricID,
        timestamp: Date,
        day: Date,
        state: MetricObservationState,
        source: MetricSourceReference,
        qualityFlags: Set<MetricQualityFlag> = []
    ) {
        self.id = MetricObservationID(rawValue: "\(metricID.rawValue)|\(source.stableKey)")
        self.metricID = metricID
        self.timestamp = timestamp
        self.day = day
        self.state = state
        self.source = source
        self.qualityFlags = qualityFlags
    }
}

enum MetricEventAttribute: Equatable, Sendable {
    case text(String)
    case number(Double)
    case boolean(Bool)
}

struct MetricRawEvent: Identifiable, Equatable, Sendable {
    let id: MetricObservationID
    let metricID: MetricID
    let timestamp: Date
    let day: Date
    let source: MetricSourceReference
    let attributes: [String: MetricEventAttribute]

    init(
        metricID: MetricID,
        timestamp: Date,
        day: Date,
        source: MetricSourceReference,
        attributes: [String: MetricEventAttribute] = [:]
    ) {
        self.id = MetricObservationID(rawValue: "event|\(metricID.rawValue)|\(source.stableKey)")
        self.metricID = metricID
        self.timestamp = timestamp
        self.day = day
        self.source = source
        self.attributes = attributes
    }
}

struct MetricObservationBatch: Equatable, Sendable {
    var observations: [MetricObservation]
    var rawEvents: [MetricRawEvent]

    static let empty = MetricObservationBatch(observations: [], rawEvents: [])

    mutating func append(_ other: MetricObservationBatch) {
        observations.append(contentsOf: other.observations)
        rawEvents.append(contentsOf: other.rawEvents)
    }
}

// MARK: - Day normalization

/// A single, injected definition of an analytics day. Repository and device defaults must not
/// leak into normalization, particularly around DST transitions or while traveling.
struct MetricDayNormalizer: Sendable {
    let calendar: Calendar
    let timeZone: TimeZone

    init(calendar: Calendar = Calendar(identifier: .gregorian), timeZone: TimeZone) {
        var configuredCalendar = calendar
        configuredCalendar.timeZone = timeZone
        self.calendar = configuredCalendar
        self.timeZone = timeZone
    }

    func day(containing date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return [
            timeZone.identifier,
            String(components.era ?? 0),
            String(components.year ?? 0),
            String(components.month ?? 0),
            String(components.day ?? 0)
        ].joined(separator: ":")
    }
}

// MARK: - Deterministic daily reduction

struct MetricDailyReducer {
    let normalizer: MetricDayNormalizer

    func reduce(_ batch: MetricObservationBatch, definitions: [MetricDefinition]) -> MetricObservationBatch {
        let definitionsByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: batch.observations) { observation in
            ReductionKey(metricID: observation.metricID, dayKey: normalizer.dayKey(for: observation.day))
        }

        let observations = grouped.keys.sorted().flatMap { key -> [MetricObservation] in
            let values = (grouped[key] ?? []).sorted(by: Self.observationOrder)
            guard let definition = definitionsByID[key.metricID] else { return values }
            return reduce(values, with: definition, dayKey: key.dayKey)
        }

        return MetricObservationBatch(
            observations: observations,
            rawEvents: batch.rawEvents.sorted(by: Self.eventOrder)
        )
    }

    private func reduce(
        _ observations: [MetricObservation],
        with definition: MetricDefinition,
        dayKey: String
    ) -> [MetricObservation] {
        guard definition.aggregation.daily != .none else { return observations }
        guard let first = observations.first else { return [] }

        let observed = observations.compactMap { observation -> MetricObservedValue? in
            guard case .observed(let value) = observation.state else { return nil }
            return value
        }

        let state: MetricObservationState
        if observed.isEmpty {
            state = fallbackState(from: observations)
        } else {
            state = reducedState(observed, reducer: definition.aggregation.daily)
        }

        let latestTimestamp = observations.map(\.timestamp).max() ?? first.timestamp
        let source = MetricSourceReference(
            kind: .dailyReduction,
            recordID: dayKey,
            field: "\(definition.id.rawValue):\(definition.aggregation.daily.rawValue)"
        )

        return [MetricObservation(
            metricID: definition.id,
            timestamp: latestTimestamp,
            day: normalizer.day(containing: first.day),
            state: state,
            source: source,
            qualityFlags: observations.reduce(Set([MetricQualityFlag.dailyReduction])) {
                $0.union($1.qualityFlags)
            }
        )]
    }

    private func fallbackState(from observations: [MetricObservation]) -> MetricObservationState {
        if observations.contains(where: { $0.state == .explicitNone }) { return .explicitNone }
        if observations.contains(where: { $0.state == .notApplicable }) { return .notApplicable }
        return .missing
    }

    private func reducedState(
        _ values: [MetricObservedValue],
        reducer: MetricAggregationReducer
    ) -> MetricObservationState {
        switch reducer {
        case .latest:
            return .observed(values.last!)
        case .count:
            return .observed(.number(Double(values.count)))
        case .sum:
            return numeric(values) { $0.reduce(0, +) }
        case .average:
            return numeric(values) { $0.reduce(0, +) / Double($0.count) }
        case .median:
            return numeric(values) { numbers in
                let sorted = numbers.sorted()
                let middle = sorted.count / 2
                return sorted.count.isMultiple(of: 2)
                    ? (sorted[middle - 1] + sorted[middle]) / 2
                    : sorted[middle]
            }
        case .occurrenceRate:
            let booleans = values.compactMap { value -> Bool? in
                guard case .boolean(let result) = value else { return nil }
                return result
            }
            guard !booleans.isEmpty else { return .missing }
            return .observed(.ratio(numerator: booleans.filter { $0 }.count, denominator: booleans.count))
        case .weightedPercentage:
            let ratios = values.compactMap { value -> (Int, Int)? in
                guard case .ratio(let numerator, let denominator) = value, denominator > 0 else { return nil }
                return (numerator, denominator)
            }
            guard !ratios.isEmpty else { return .notApplicable }
            return .observed(.ratio(
                numerator: ratios.reduce(0) { $0 + $1.0 },
                denominator: ratios.reduce(0) { $0 + $1.1 }
            ))
        case .distribution:
            let counts = Dictionary(grouping: values, by: \.bucketKey).mapValues(\.count)
            let buckets = counts.keys.sorted().map { MetricDistributionBucket(value: $0, count: counts[$0]!) }
            return .observed(.distribution(buckets))
        case .mode:
            let groups = Dictionary(grouping: values, by: \.bucketKey)
            let selected = groups.sorted {
                if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
                return $0.key < $1.key
            }.first?.value.first
            return selected.map { .observed($0) } ?? .missing
        case .none:
            return .observed(values.last!)
        }
    }

    private func numeric(
        _ values: [MetricObservedValue],
        operation: ([Double]) -> Double
    ) -> MetricObservationState {
        let numbers = values.compactMap(\.numericValue)
        guard !numbers.isEmpty else { return .missing }
        return .observed(.number(operation(numbers)))
    }

    private static func observationOrder(_ lhs: MetricObservation, _ rhs: MetricObservation) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    private static func eventOrder(_ lhs: MetricRawEvent, _ rhs: MetricRawEvent) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    private struct ReductionKey: Hashable, Comparable {
        let metricID: MetricID
        let dayKey: String

        static func < (lhs: ReductionKey, rhs: ReductionKey) -> Bool {
            if lhs.metricID.rawValue != rhs.metricID.rawValue {
                return lhs.metricID.rawValue < rhs.metricID.rawValue
            }
            return lhs.dayKey < rhs.dayKey
        }
    }
}
