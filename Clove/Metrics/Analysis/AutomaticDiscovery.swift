import Foundation

struct DiscoveryConfiguration: Equatable, Sendable {
    var maximumTests = 60
    var minimumCoverage = 0.4
    var minimumAbsoluteEffect = 0.3
    var falseDiscoveryRate = 0.1
    var maximumResults = 12
}

struct AutomaticDiscovery: Identifiable, Equatable, Sendable {
    let id: String
    let factor: MetricDefinition
    let outcome: MetricDefinition
    let estimate: RelationshipEstimate
    let qValue: Double
    let matchedCoverage: Double
    let rankScore: Double
    let limitations: [String]

    var title: String { "\(factor.displayName) and \(outcome.displayName)" }
}

struct DiscoveryRun: Equatable, Sendable {
    let discoveries: [AutomaticDiscovery]
    let eligiblePairCount: Int
    let testedPairCount: Int
    let testBudget: Int
    let wasBudgetLimited: Bool
    let falseDiscoveryRate: Double
    let limitations: [String]
}

struct AutomaticDiscoveryEngine {
    func scan(dataset: AnalyticsDataset, configuration: DiscoveryConfiguration = DiscoveryConfiguration()) -> DiscoveryRun {
        let definitions = dataset.definitions.filter { definition in
            definition.supportedAnalyses.contains(.relationship)
                && (dataset.coverage[definition.id]?.observedDayFraction ?? 0) >= configuration.minimumCoverage
                && (dataset.coverage[definition.id]?.sourceDayCount ?? 0) >= definition.minimumSamples.relationship
        }.sorted { $0.id.rawValue < $1.id.rawValue }

        var candidates: [(MetricDefinition, MetricDefinition)] = []
        for left in definitions.indices {
            for right in definitions.indices where right > left {
                let pair = (definitions[left], definitions[right])
                if RelationshipMethodSelector().select(factor: pair.0, outcome: pair.1) != nil { candidates.append(pair) }
            }
        }
        let eligibleCount = candidates.count
        candidates = Array(candidates.prefix(configuration.maximumTests))

        struct Tested {
            let factor: MetricDefinition
            let outcome: MetricDefinition
            let estimate: RelationshipEstimate
            let coverage: Double
            let recency: Double
        }
        var tested: [Tested] = []
        let aligner = PairAlignmentEngine()
        let statistics = RelationshipStatisticsEngine()
        for (factor, outcome) in candidates {
            let alignment = aligner.align(factor: factor, outcome: outcome, dataset: dataset)
            let estimate = statistics.estimate(alignment: alignment, factor: factor, outcome: outcome)
            guard estimate.isSufficient, estimate.pValue != nil else { continue }
            let latest = [dataset.coverage[factor.id]?.lastObservation, dataset.coverage[outcome.id]?.lastObservation]
                .compactMap { $0 }.min() ?? dataset.interval.start
            let daysOld = max(0, dataset.interval.end.timeIntervalSince(latest) / 86_400)
            tested.append(Tested(factor: factor, outcome: outcome, estimate: estimate,
                                 coverage: alignment.coverage.matchedFraction,
                                 recency: exp(-daysOld / 30)))
        }

        let qValues = benjaminiHochberg(tested.compactMap { $0.estimate.pValue })
        var discoveries: [AutomaticDiscovery] = []
        for (index, value) in tested.enumerated() {
            guard let effect = value.estimate.effect, abs(effect) >= configuration.minimumAbsoluteEffect,
                  qValues[index] <= configuration.falseDiscoveryRate else { continue }
            let intervalWidth = value.estimate.confidenceInterval.map { $0.upperBound - $0.lowerBound } ?? 2
            let precision = max(0, 1 - min(1, intervalWidth / 2))
            let actionable = value.factor.directionality == .neutral && value.outcome.directionality == .neutral ? 0.25 : 1.0
            let score = abs(effect) * 0.4 + precision * 0.2 + value.coverage * 0.2 + value.recency * 0.1 + actionable * 0.1
            let method = value.estimate.method.rawValue
            let id = [value.factor.id.rawValue, value.outcome.id.rawValue].sorted().joined(separator: "|") + "|\(method)"
            discoveries.append(AutomaticDiscovery(id: id, factor: value.factor, outcome: value.outcome,
                estimate: value.estimate, qValue: qValues[index], matchedCoverage: value.coverage, rankScore: score,
                limitations: value.estimate.limitations + [
                    "This was found by an exploratory scan of \(candidates.count) metric pairs.",
                    "The false-discovery-rate adjustment reduces, but does not eliminate, chance findings."
                ]))
        }
        discoveries.sort { $0.rankScore == $1.rankScore ? $0.id < $1.id : $0.rankScore > $1.rankScore }
        discoveries = Array(discoveries.prefix(configuration.maximumResults))
        return DiscoveryRun(discoveries: discoveries, eligiblePairCount: eligibleCount,
            testedPairCount: candidates.count, testBudget: configuration.maximumTests,
            wasBudgetLimited: eligibleCount > candidates.count, falseDiscoveryRate: configuration.falseDiscoveryRate,
            limitations: [
                "Discoveries are exploratory associations, not proof that one metric affects another.",
                "Benjamini–Hochberg correction was applied across every test with an estimable p-value in this run."
            ])
    }

    func benjaminiHochberg(_ pValues: [Double]) -> [Double] {
        guard !pValues.isEmpty else { return [] }
        let ordered = pValues.enumerated().sorted { $0.element < $1.element }
        var adjusted = Array(repeating: 1.0, count: pValues.count)
        var running = 1.0
        for position in stride(from: ordered.count - 1, through: 0, by: -1) {
            let raw = ordered[position].element * Double(ordered.count) / Double(position + 1)
            running = min(running, raw)
            adjusted[ordered[position].offset] = min(1, max(0, running))
        }
        return adjusted
    }
}
