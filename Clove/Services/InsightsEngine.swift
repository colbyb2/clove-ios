import Foundation

enum InsightType: String, CaseIterable, Codable, Sendable {
    case trend, achievement, pattern, correlation, warning, recommendation
}

enum InsightPriority: Int, CaseIterable, Codable, Sendable {
    case low = 1, medium = 2, high = 3, critical = 4
}

enum InsightEvidenceQuality: String, Codable, Sendable {
    case earlySignal = "Early signal"
    case limited = "Limited"
    case fair = "Fair"
    case strong = "Strong"
}

struct InsightProvenance: Hashable, Sendable {
    let generator: String
    let metricIDs: [MetricID]
    let interval: DateInterval
    let observedDayCount: Int
    let possibleDayCount: Int
    let calculation: String
}

struct InsightEvidence: Hashable, Sendable {
    let effect: Double?
    let unitLabel: String?
    let sampleCount: Int
    let coverage: Double
    let quality: InsightEvidenceQuality
    let provenance: InsightProvenance
    let limitations: [String]

    var whyText: String {
        "Based on \(sampleCount) recorded observations across \(provenance.observedDayCount) of \(provenance.possibleDayCount) eligible days using \(provenance.calculation)."
    }
}

enum InsightPresentationHint: String, Codable, Sendable {
    case change, streak, weekday, volatility, coverage, achievement
}

struct HealthInsight: Identifiable, Hashable, Sendable {
    let id: String
    let type: InsightType
    let priority: InsightPriority
    let title: String
    let description: String
    let actionableText: String?
    let confidence: Double
    let relevancePeriod: DateInterval
    let associatedMetrics: [String]
    let generatedAt: Date
    let isActionable: Bool
    let evidence: InsightEvidence?
    let presentationHint: InsightPresentationHint?

    init(id: String? = nil, type: InsightType, priority: InsightPriority, title: String, description: String,
         actionableText: String?, confidence: Double, relevancePeriod: DateInterval,
         associatedMetrics: [String], generatedAt: Date, isActionable: Bool,
         evidence: InsightEvidence? = nil, presentationHint: InsightPresentationHint? = nil) {
        self.type = type; self.priority = priority; self.title = title; self.description = description
        self.actionableText = actionableText; self.confidence = max(0, min(1, evidence.map(Self.confidence) ?? confidence))
        self.relevancePeriod = relevancePeriod; self.associatedMetrics = associatedMetrics.sorted()
        self.generatedAt = generatedAt; self.isActionable = isActionable
        self.evidence = evidence; self.presentationHint = presentationHint
        self.id = id ?? Self.stableID(type: type, metrics: associatedMetrics, hint: presentationHint)
    }

    var priorityColor: String { priority == .critical ? "purple" : priority == .high ? "red" : priority == .medium ? "orange" : "blue" }
    var typeIcon: String {
        switch type {
        case .trend: return "chart.line.uptrend.xyaxis"
        case .achievement: return "star.fill"
        case .pattern: return "calendar"
        case .correlation: return "link"
        case .warning: return "exclamationmark.triangle.fill"
        case .recommendation: return "lightbulb.fill"
        }
    }

    private static func stableID(type: InsightType, metrics: [String], hint: InsightPresentationHint?) -> String {
        ([type.rawValue] + metrics.sorted() + [hint?.rawValue ?? "general"]).joined(separator: "|")
    }

    private static func confidence(_ evidence: InsightEvidence) -> Double {
        let quality: Double = switch evidence.quality { case .earlySignal: 0.25; case .limited: 0.45; case .fair: 0.7; case .strong: 0.9 }
        return min(1, quality * (0.6 + 0.4 * evidence.coverage))
    }
}

enum InsightCopyPolicy {
    private static let prohibited = ["causes", "cures", "diagnoses", "treats", "will improve", "will reduce", "medical advice"]
    static func isAllowed(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return !prohibited.contains { normalized.contains($0) }
    }
}

struct InsightGenerator {
    func generate(dataset: AnalyticsDataset, previous: AnalyticsDataset? = nil, generatedAt: Date = Date()) -> [HealthInsight] {
        let candidates = dataset.definitions.flatMap { definition in
            metricInsights(definition: definition, dataset: dataset, previous: previous, generatedAt: generatedAt)
        }
        var byID: [String: HealthInsight] = [:]
        for insight in candidates where InsightCopyPolicy.isAllowed(insight.title + " " + insight.description + " " + (insight.actionableText ?? "")) {
            if let old = byID[insight.id], old.priority.rawValue >= insight.priority.rawValue { continue }
            byID[insight.id] = insight
        }
        return byID.values.sorted { lhs, rhs in
            lhs.priority.rawValue == rhs.priority.rawValue ? lhs.id < rhs.id : lhs.priority.rawValue > rhs.priority.rawValue
        }
    }

    private func metricInsights(definition: MetricDefinition, dataset: AnalyticsDataset, previous: AnalyticsDataset?, generatedAt: Date) -> [HealthInsight] {
        let observations = numeric(dataset.observations(for: definition.id))
        let coverage = dataset.coverage[definition.id]
        guard let coverage, !observations.isEmpty else { return [] }
        var result: [HealthInsight] = []
        if let previous {
            let summary = MetricAnalysisSummaryEngine().summarize(definition: definition, dataset: dataset, previousDataset: previous)
            if let comparison = summary.comparison, let change = comparison.absoluteChange,
               comparison.currentCoverage.sourceDayCount >= 4, comparison.previousCoverage.sourceDayCount >= 4,
               meaningfulChange(change, values: observations.map(\.value)) {
                let quality = evidenceQuality(count: observations.count, coverage: coverage.observedDayFraction)
                let favorability = comparison.favorability
                let type: InsightType = favorability == .unfavorable ? .warning : (favorability == .favorable ? .achievement : .trend)
                let direction = change > 0 ? "higher" : "lower"
                let evidence = makeEvidence(generator: "period-change", definition: definition, dataset: dataset, coverage: coverage,
                                            count: observations.count, effect: change, quality: quality,
                                            calculation: "equal-length period summaries",
                                            limitations: commonLimitations(coverage: coverage))
                result.append(HealthInsight(type: type, priority: quality == .strong ? .high : .medium,
                    title: "\(definition.displayName) was \(direction)",
                    description: "The current period averaged \(format(abs(change), definition: definition)) \(direction) than the previous period.",
                    actionableText: "Open the metric to inspect the recorded days.", confidence: 0,
                    relevancePeriod: dataset.interval, associatedMetrics: [definition.id.rawValue], generatedAt: generatedAt,
                    isActionable: true, evidence: evidence, presentationHint: .change))
            }
        }
        if let trend = robustTrend(observations), observations.count >= max(7, definition.minimumSamples.pattern), trend.isMeaningful {
            let direction: MetricChangeDirection = trend.totalChange > 0 ? .increasing : .decreasing
            let favorability = definition.directionality.favorability(of: direction)
            let quality = evidenceQuality(count: observations.count, coverage: coverage.observedDayFraction)
            let evidence = makeEvidence(generator: "robust-trend", definition: definition, dataset: dataset, coverage: coverage,
                count: observations.count, effect: trend.totalChange, quality: quality, calculation: "median pairwise daily slope",
                limitations: commonLimitations(coverage: coverage))
            result.append(HealthInsight(type: favorability == .unfavorable ? .warning : .trend,
                priority: favorability == .unfavorable ? .high : .medium,
                title: "\(definition.displayName) has been trending \(trend.totalChange > 0 ? "up" : "down")",
                description: "The robust trend changed by about \(format(abs(trend.totalChange), definition: definition)) across this period.",
                actionableText: nil, confidence: 0, relevancePeriod: dataset.interval,
                associatedMetrics: [definition.id.rawValue], generatedAt: generatedAt, isActionable: false,
                evidence: evidence, presentationHint: .change))
        }
        if let weekday = weekdayPattern(observations), weekday.count >= 3 {
            let quality = evidenceQuality(count: observations.count, coverage: coverage.observedDayFraction)
            let evidence = makeEvidence(generator: "weekday-pattern", definition: definition, dataset: dataset, coverage: coverage,
                count: observations.count, effect: weekday.difference, quality: quality,
                calculation: "weekday averages with at least three observations per compared group",
                limitations: commonLimitations(coverage: coverage))
            result.append(HealthInsight(type: .pattern, priority: .medium, title: "A recurring \(weekday.name) pattern",
                description: "Recorded \(definition.displayName.lowercased()) was about \(format(abs(weekday.difference), definition: definition)) \(weekday.difference > 0 ? "higher" : "lower") on \(weekday.name)s than on other recorded days.",
                actionableText: nil, confidence: 0, relevancePeriod: dataset.interval,
                associatedMetrics: [definition.id.rawValue], generatedAt: generatedAt, isActionable: false,
                evidence: evidence, presentationHint: .weekday))
        }
        if let volatility = volatilityChange(observations), volatility.ratio >= 2 {
            let quality = evidenceQuality(count: observations.count, coverage: coverage.observedDayFraction)
            let evidence = makeEvidence(generator: "volatility-change", definition: definition, dataset: dataset, coverage: coverage,
                count: observations.count, effect: volatility.ratio, quality: quality,
                calculation: "median absolute deviation in the first and second halves of the period",
                limitations: commonLimitations(coverage: coverage))
            result.append(HealthInsight(type: .pattern, priority: .medium,
                title: "\(definition.displayName) became more variable",
                description: "Recorded values varied about \(volatility.ratio.formatted(.number.precision(.fractionLength(1))))× as much in the second half of this period.",
                actionableText: "Open the metric to inspect when the variation changed.", confidence: 0,
                relevancePeriod: dataset.interval, associatedMetrics: [definition.id.rawValue], generatedAt: generatedAt,
                isActionable: true, evidence: evidence, presentationHint: .volatility))
        }
        if let streak = recordingStreak(dataset.observations(for: definition.id)), streak >= 3 {
            let quality = evidenceQuality(count: observations.count, coverage: coverage.observedDayFraction)
            let evidence = makeEvidence(generator: "recording-streak", definition: definition, dataset: dataset, coverage: coverage,
                count: observations.count, effect: Double(streak), quality: quality, calculation: "consecutive calendar days with observed values",
                limitations: ["Missing days end a streak; they are not treated as negative observations."])
            result.append(HealthInsight(type: .achievement, priority: .low, title: "\(streak)-day \(definition.displayName) tracking streak",
                description: "You recorded this metric on \(streak) consecutive calendar days.", actionableText: nil,
                confidence: 0, relevancePeriod: dataset.interval, associatedMetrics: [definition.id.rawValue], generatedAt: generatedAt,
                isActionable: false, evidence: evidence, presentationHint: .streak))
        }
        return result
    }

    private func numeric(_ observations: [MetricObservation]) -> [(date: Date, value: Double)] {
        observations.compactMap { observation in
            guard case .observed(let value) = observation.state, let numeric = value.numericValue else { return nil }
            return (observation.day, numeric)
        }.sorted { $0.date < $1.date }
    }

    private func meaningfulChange(_ change: Double, values: [Double]) -> Bool {
        guard values.count >= 4 else { return false }
        let sorted = values.sorted(); let spread = sorted[Int(Double(sorted.count - 1) * 0.75)] - sorted[Int(Double(sorted.count - 1) * 0.25)]
        return abs(change) >= max(0.01, spread * 0.35)
    }

    private func robustTrend(_ values: [(date: Date, value: Double)]) -> (totalChange: Double, isMeaningful: Bool)? {
        guard values.count >= 7 else { return nil }
        var slopes: [Double] = []
        for i in values.indices { for j in values.indices where j > i {
            let days = values[j].date.timeIntervalSince(values[i].date) / 86_400
            if days > 0 { slopes.append((values[j].value - values[i].value) / days) }
        }}
        guard !slopes.isEmpty else { return nil }
        slopes.sort(); let slope = slopes[slopes.count / 2]
        let total = slope * max(1, values.last!.date.timeIntervalSince(values.first!.date) / 86_400)
        let sorted = values.map(\.value).sorted(); let spread = sorted[Int(Double(sorted.count - 1) * 0.75)] - sorted[Int(Double(sorted.count - 1) * 0.25)]
        return (total, abs(total) >= max(0.1, spread * 0.75))
    }

    private func weekdayPattern(_ values: [(date: Date, value: Double)]) -> (name: String, difference: Double, count: Int)? {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: values) { calendar.component(.weekday, from: $0.date) }
        let eligible = groups.filter { $0.value.count >= 3 }
        guard eligible.count >= 2 else { return nil }
        let allMean = values.reduce(0) { $0 + $1.value } / Double(values.count)
        let candidates = eligible.map { weekday, values -> (Int, Double, Int) in
            (weekday, values.reduce(0) { $0 + $1.value } / Double(values.count) - allMean, values.count)
        }
        guard let strongest = candidates.max(by: { abs($0.1) < abs($1.1) }) else { return nil }
        let allValues = values.map(\.value).sorted()
        let spread = allValues[Int(Double(allValues.count - 1) * 0.75)] - allValues[Int(Double(allValues.count - 1) * 0.25)]
        guard abs(strongest.1) >= max(0.1, spread * 0.5) else { return nil }
        return (calendar.weekdaySymbols[strongest.0 - 1], strongest.1, strongest.2)
    }

    private func recordingStreak(_ observations: [MetricObservation]) -> Int? {
        let calendar = Calendar.current
        let days = Set(observations.compactMap { observation -> Date? in
            if case .observed = observation.state { return calendar.startOfDay(for: observation.day) }
            return nil
        }).sorted()
        guard !days.isEmpty else { return nil }
        var best = 1, current = 1
        for index in 1..<days.count {
            if calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day == 1 { current += 1; best = max(best, current) }
            else { current = 1 }
        }
        return best
    }

    private func volatilityChange(_ values: [(date: Date, value: Double)]) -> (ratio: Double, firstMAD: Double, secondMAD: Double)? {
        guard values.count >= 14 else { return nil }
        let midpoint = values.count / 2
        let first = Array(values[..<midpoint]).map(\.value)
        let second = Array(values[midpoint...]).map(\.value)
        guard first.count >= 7, second.count >= 7 else { return nil }
        let firstMAD = medianAbsoluteDeviation(first)
        let secondMAD = medianAbsoluteDeviation(second)
        guard secondMAD >= 0.1, secondMAD > firstMAD else { return nil }
        return (secondMAD / max(0.05, firstMAD), firstMAD, secondMAD)
    }

    private func medianAbsoluteDeviation(_ values: [Double]) -> Double {
        let center = median(values)
        return median(values.map { abs($0 - center) })
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private func evidenceQuality(count: Int, coverage: Double) -> InsightEvidenceQuality {
        if count < 7 { return .earlySignal }
        if count >= 30 && coverage >= 0.75 { return .strong }
        if count >= 14 && coverage >= 0.5 { return .fair }
        return .limited
    }

    private func makeEvidence(generator: String, definition: MetricDefinition, dataset: AnalyticsDataset, coverage: MetricCoverage,
                              count: Int, effect: Double?, quality: InsightEvidenceQuality, calculation: String,
                              limitations: [String]) -> InsightEvidence {
        InsightEvidence(effect: effect, unitLabel: unit(definition.unit), sampleCount: count,
            coverage: coverage.observedDayFraction, quality: quality,
            provenance: InsightProvenance(generator: generator, metricIDs: [definition.id], interval: dataset.interval,
                observedDayCount: coverage.sourceDayCount, possibleDayCount: coverage.possibleDayCount, calculation: calculation),
            limitations: limitations)
    }

    private func commonLimitations(coverage: MetricCoverage) -> [String] {
        var values = ["This describes recorded data and does not establish causation."]
        if coverage.observedDayFraction < 0.5 { values.append("Fewer than half of eligible days contain source data, so this is an early signal.") }
        return values
    }

    private func format(_ value: Double, definition: MetricDefinition) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...max(1, definition.displayFormat.maximumFractionDigits))))
        return number + (definition.displayFormat.suffix.map { " \($0)" } ?? unit(definition.unit).map { " \($0)" } ?? "")
    }

    private func unit(_ unit: MetricUnit) -> String? {
        switch unit { case .score: return "points"; case .count: return "events"; case .percentage: return "%"; case .fluidOunces: return "fl oz"; case .minutes: return "minutes"; case .category, .occurrence: return nil; case .custom(let symbol): return symbol }
    }
}

@MainActor
@Observable
final class InsightsEngine {
    static let shared = InsightsEngine()
    var currentInsights: [HealthInsight] = []
    var isGeneratingInsights = false
    var lastGenerationTime: Date?

    private init() {}

    func generateInsights(forPeriod period: TimePeriod = .month) async {
        isGeneratingInsights = true
        defer { isGeneratingInsights = false }
        do {
            let rangeFactory = AnalyticsDateRangeFactory()
            let interval = rangeFactory.interval(for: period)
            let granularity = AnalyticsChartPipeline().granularity(for: interval)
            let current = try await AnalyticsRepositoryContainer.shared.load(
                AnalyticsRequest(interval: interval, includeRawEvents: true), granularity: granularity
            )
            let previous: AnalyticsDataset?
            if let previousInterval = rangeFactory.previous(equalTo: interval), period != .allTime {
                previous = try? await AnalyticsRepositoryContainer.shared.load(
                    AnalyticsRequest(interval: previousInterval, includeRawEvents: true),
                    granularity: AnalyticsChartPipeline().granularity(for: previousInterval)
                )
            } else {
                previous = nil
            }
            let generatedAt = Date()
            currentInsights = InsightGenerator().generate(dataset: current, previous: previous, generatedAt: generatedAt)
            lastGenerationTime = generatedAt
        } catch { currentInsights = [] }
    }

    func getInsights(ofType type: InsightType) -> [HealthInsight] { currentInsights.filter { $0.type == type } }
    func getHighPriorityInsights() -> [HealthInsight] { currentInsights.filter { $0.priority.rawValue >= InsightPriority.high.rawValue } }
    func getActionableInsights() -> [HealthInsight] { currentInsights.filter(\.isActionable) }
}
