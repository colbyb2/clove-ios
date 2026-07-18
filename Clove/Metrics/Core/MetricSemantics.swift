import Foundation

// MARK: - Stable Identity

/// Stable, persistence-safe identity for an analytics metric.
///
/// New identifiers should be lowercase and namespaced when they are dynamic, for example
/// `symptom:42`. Legacy identifiers remain valid during the incremental migration.
struct MetricID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    var description: String { rawValue }

    var isValid: Bool {
        !rawValue.isEmpty && rawValue.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar) && !CharacterSet.controlCharacters.contains(scalar)
        }
    }
}

// MARK: - Meaning

enum MetricMeasurementLevel: String, CaseIterable, Codable, Sendable {
    case continuous
    case ordinal
    case binary
    case categorical
    case count
    case event
    case percentage
    case custom
}

enum MetricSemanticCategory: String, CaseIterable, Codable, Sendable {
    case coreHealth
    case symptoms
    case medications
    case lifestyle
    case environmental
    case activities
    case meals
}

enum MetricSource: Equatable, Codable, Sendable {
    case dailyLog(field: String)
    case symptomRatings
    case medicationRecords
    case foodEntries
    case activityEntries
    case bowelMovements
    case cycleEntries
    case derived(from: [MetricID])
}

enum MetricUnit: Equatable, Codable, Sendable {
    case score
    case count
    case percentage
    case fluidOunces
    case minutes
    case category
    case occurrence
    case custom(symbol: String)
}

enum MetricValueDomain: Equatable, Sendable {
    case numeric(ClosedRange<Double>)
    case nonNegative
    case categories([String])
    case unrestricted
}

enum MetricDirectionality: String, CaseIterable, Codable, Sendable {
    case higherIsBetter
    case lowerIsBetter
    case neutral

    func favorability(of direction: MetricChangeDirection) -> MetricChangeFavorability {
        switch (self, direction) {
        case (_, .stable), (.neutral, _):
            return .neutral
        case (.higherIsBetter, .increasing), (.lowerIsBetter, .decreasing):
            return .favorable
        case (.higherIsBetter, .decreasing), (.lowerIsBetter, .increasing):
            return .unfavorable
        }
    }
}

enum MetricChangeDirection: String, CaseIterable, Codable, Sendable {
    case increasing
    case decreasing
    case stable
}

enum MetricChangeFavorability: String, CaseIterable, Codable, Sendable {
    case favorable
    case unfavorable
    case neutral
}

/// Defines how a day with no source record may be interpreted.
enum MetricUnrecordedDayPolicy: String, CaseIterable, Codable, Sendable {
    /// Absence of a record reveals nothing about the metric.
    case missing
    /// The source guarantees that no record means a numeric zero.
    case zero
    /// The source guarantees that no record means an explicitly absent event or condition.
    case explicitNone
    /// The metric was not eligible or meaningful on unrecorded days.
    case notApplicable
}

// MARK: - Aggregation and Analysis

enum MetricAggregationReducer: String, CaseIterable, Codable, Sendable {
    case average
    case median
    case sum
    case count
    case occurrenceRate
    case weightedPercentage
    case distribution
    case mode
    case latest
    case none
}

struct MetricAggregationPolicy: Equatable, Codable, Sendable {
    let daily: MetricAggregationReducer
    let weekly: MetricAggregationReducer
    let monthly: MetricAggregationReducer

    init(
        daily: MetricAggregationReducer,
        weekly: MetricAggregationReducer,
        monthly: MetricAggregationReducer
    ) {
        self.daily = daily
        self.weekly = weekly
        self.monthly = monthly
    }
}

enum MetricAnalysisKind: String, CaseIterable, Codable, Sendable {
    case descriptive
    case trend
    case distribution
    case frequency
    case periodComparison
    case relationship
    case laggedRelationship
    case eventOutcome
}

struct MetricMinimumSamples: Equatable, Codable, Sendable {
    let descriptive: Int
    let trend: Int
    let relationship: Int
    let pattern: Int

    init(descriptive: Int = 1, trend: Int = 3, relationship: Int = 3, pattern: Int = 7) {
        self.descriptive = descriptive
        self.trend = trend
        self.relationship = relationship
        self.pattern = pattern
    }

    var isValid: Bool {
        [descriptive, trend, relationship, pattern].allSatisfy { $0 > 0 }
    }
}

enum MetricVisualization: String, CaseIterable, Codable, Sendable {
    case line
    case area
    case bar
    case stackedBar
    case scatter
    case occurrenceStrip
    case calendarHeatmap
    case distribution
    case eventOverlay
    case automatic
}

struct MetricDisplayFormat: Equatable, Codable, Sendable {
    let maximumFractionDigits: Int
    let suffix: String?

    init(maximumFractionDigits: Int = 0, suffix: String? = nil) {
        self.maximumFractionDigits = maximumFractionDigits
        self.suffix = suffix
    }
}

// MARK: - Definition

struct MetricDefinition: Identifiable, Equatable, Sendable {
    let id: MetricID
    let displayName: String
    let description: String
    let category: MetricSemanticCategory
    let source: MetricSource
    let measurementLevel: MetricMeasurementLevel
    let unit: MetricUnit
    let domain: MetricValueDomain
    let directionality: MetricDirectionality
    let aggregation: MetricAggregationPolicy
    let unrecordedDayPolicy: MetricUnrecordedDayPolicy
    let supportedAnalyses: Set<MetricAnalysisKind>
    let minimumSamples: MetricMinimumSamples
    let recommendedVisualizations: [MetricVisualization]
    let displayFormat: MetricDisplayFormat

    init(
        id: MetricID,
        displayName: String,
        description: String,
        category: MetricSemanticCategory,
        source: MetricSource,
        measurementLevel: MetricMeasurementLevel,
        unit: MetricUnit,
        domain: MetricValueDomain,
        directionality: MetricDirectionality,
        aggregation: MetricAggregationPolicy,
        unrecordedDayPolicy: MetricUnrecordedDayPolicy,
        supportedAnalyses: Set<MetricAnalysisKind>,
        minimumSamples: MetricMinimumSamples = MetricMinimumSamples(),
        recommendedVisualizations: [MetricVisualization],
        displayFormat: MetricDisplayFormat = MetricDisplayFormat()
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.category = category
        self.source = source
        self.measurementLevel = measurementLevel
        self.unit = unit
        self.domain = domain
        self.directionality = directionality
        self.aggregation = aggregation
        self.unrecordedDayPolicy = unrecordedDayPolicy
        self.supportedAnalyses = supportedAnalyses
        self.minimumSamples = minimumSamples
        self.recommendedVisualizations = recommendedVisualizations
        self.displayFormat = displayFormat
    }

    var validationIssues: [MetricDefinitionValidationIssue] {
        var issues: [MetricDefinitionValidationIssue] = []

        if !id.isValid { issues.append(.invalidID) }
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missingDisplayName)
        }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missingDescription)
        }
        if !minimumSamples.isValid { issues.append(.invalidMinimumSamples) }
        if displayFormat.maximumFractionDigits < 0 { issues.append(.invalidDisplayFormat) }
        if recommendedVisualizations.isEmpty { issues.append(.missingVisualization) }

        switch source {
        case .dailyLog(let field):
            if field.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.invalidSource)
            }
        case .derived(let metricIDs):
            if metricIDs.isEmpty || metricIDs.contains(where: { !$0.isValid }) {
                issues.append(.invalidSource)
            }
        default:
            break
        }

        if case .categories(let values) = domain {
            let normalized = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            if normalized.isEmpty || normalized.contains(where: { $0.isEmpty }) || Set(normalized).count != normalized.count {
                issues.append(.invalidCategories)
            }
        }

        if measurementLevel == .categorical {
            if case .categories = domain {} else { issues.append(.incompatibleDomain) }
        }
        if measurementLevel == .binary {
            if case .numeric(let range) = domain, range.lowerBound == 0, range.upperBound == 1 {
                // Valid binary domain.
            } else {
                issues.append(.incompatibleDomain)
            }
        }
        if measurementLevel == .percentage {
            if case .numeric(let range) = domain, range.lowerBound == 0, range.upperBound == 100 {
                // Valid percentage domain.
            } else {
                issues.append(.incompatibleDomain)
            }
        }

        for reducer in [aggregation.daily, aggregation.weekly, aggregation.monthly] {
            if !Self.allowedReducers(for: measurementLevel).contains(reducer) {
                issues.append(.incompatibleReducer(reducer: reducer, measurementLevel: measurementLevel))
            }
        }

        return Array(Set(issues))
    }

    var isValid: Bool { validationIssues.isEmpty }

    private static func allowedReducers(for level: MetricMeasurementLevel) -> Set<MetricAggregationReducer> {
        switch level {
        case .continuous, .ordinal:
            return [.average, .median, .distribution, .latest]
        case .binary:
            return [.occurrenceRate, .count, .distribution, .mode, .latest]
        case .categorical:
            return [.distribution, .mode, .latest]
        case .count:
            return [.sum, .average, .median, .distribution, .latest]
        case .event:
            return [.count, .distribution, .latest, .none]
        case .percentage:
            return [.weightedPercentage, .average, .median, .distribution, .latest]
        case .custom:
            return Set(MetricAggregationReducer.allCases)
        }
    }
}

enum MetricDefinitionValidationIssue: Hashable, Sendable {
    case invalidID
    case missingDisplayName
    case missingDescription
    case invalidMinimumSamples
    case invalidDisplayFormat
    case missingVisualization
    case invalidSource
    case invalidCategories
    case incompatibleDomain
    case incompatibleReducer(reducer: MetricAggregationReducer, measurementLevel: MetricMeasurementLevel)
}
