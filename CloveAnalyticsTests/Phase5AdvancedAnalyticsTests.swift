import XCTest
@testable import Clove

final class AutomaticDiscoveryEngineTests: XCTestCase {
    func testBenjaminiHochbergMatchesReferenceAndIsMonotonic() {
        let adjusted = AutomaticDiscoveryEngine().benjaminiHochberg([0.01, 0.04, 0.03, 0.002])
        XCTAssertEqual(adjusted[0], 0.02, accuracy: 1e-12)
        XCTAssertEqual(adjusted[1], 0.04, accuracy: 1e-12)
        XCTAssertEqual(adjusted[2], 0.04, accuracy: 1e-12)
        XCTAssertEqual(adjusted[3], 0.008, accuracy: 1e-12)
        XCTAssertTrue(adjusted.allSatisfy { (0...1).contains($0) })
    }

    func testInjectedSignalSurvivesCorrectionAndHasStableIdentity() throws {
        let definitions = [discoveryDefinition("signal:x"), discoveryDefinition("signal:y")]
        let x = (1...50).map { ($0, MetricObservedValue.number(Double(($0 * 17) % 31))) }
        let y = x.map { ($0.0, MetricObservedValue.number(($0.1.numericValue ?? 0) * 2 + 1)) }
        let dataset = phase5Dataset(definitions: definitions, dayCount: 50,
                                    values: [definitions[0].id: x, definitions[1].id: y])
        let first = AutomaticDiscoveryEngine().scan(dataset: dataset)
        let second = AutomaticDiscoveryEngine().scan(dataset: dataset)

        let finding = try XCTUnwrap(first.discoveries.first)
        XCTAssertEqual(abs(try XCTUnwrap(finding.estimate.effect)), 1, accuracy: 1e-10)
        XCTAssertLessThanOrEqual(finding.qValue, first.falseDiscoveryRate)
        XCTAssertEqual(first.discoveries.map(\.id), second.discoveries.map(\.id))
    }

    func testLargeNullPopulationStaysWithinDocumentedFalsePositiveBound() {
        let definitions = (0..<10).map { discoveryDefinition(MetricID(rawValue: "null:\($0)")) }
        var values: [MetricID: [(Int, MetricObservedValue)]] = [:]
        for (index, definition) in definitions.enumerated() {
            let noise = AnalyticsSyntheticFixtures.seededNoise(seed: UInt64(101 + index * 37), count: 70)
            values[definition.id] = noise.enumerated().map {
                ($0.offset + 1, MetricObservedValue.number($0.element))
            }
        }
        let run = AutomaticDiscoveryEngine().scan(dataset: phase5Dataset(definitions: definitions, dayCount: 70, values: values))
        XCTAssertLessThanOrEqual(run.discoveries.count, 1, "A deterministic null population should not produce a page of findings")
    }

    func testHardBudgetLimitsPairEvaluation() {
        let definitions = (0..<14).map { discoveryDefinition(MetricID(rawValue: "budget:\($0)")) }
        var values: [MetricID: [(Int, MetricObservedValue)]] = [:]
        for (index, definition) in definitions.enumerated() {
            values[definition.id] = (1...30).map { day in
                (day, MetricObservedValue.number(Double((day * (index + 3)) % 23)))
            }
        }
        let configuration = DiscoveryConfiguration(maximumTests: 10, minimumCoverage: 0.4,
            minimumAbsoluteEffect: 0.3, falseDiscoveryRate: 0.1, maximumResults: 12)
        let run = AutomaticDiscoveryEngine().scan(
            dataset: phase5Dataset(definitions: definitions, dayCount: 30, values: values), configuration: configuration)
        XCTAssertGreaterThan(run.eligiblePairCount, 10)
        XCTAssertEqual(run.testedPairCount, 10)
        XCTAssertTrue(run.wasBudgetLimited)
    }
}

final class ContextAnalysisEngineTests: XCTestCase {
    func testCyclePhasesRequireRepeatedExplicitCompleteCycles() throws {
        let start = AnalyticsTestDates.date(2026, 1, 1)
        let values = (1...84).map { day -> (Int, MetricObservedValue) in
            let cycleDay = (day - 1) % 28
            return (day, .number(cycleDay <= 4 ? 9 : 3))
        }
        let dataset = phase5Dataset(definitions: [MetricCatalog.energyLevel], dayCount: 84, start: start,
                                    values: [MetricCatalog.energyLevel.id: values])
        let starts = [0, 28, 56, 84].map { AnalyticsTestDates.calendar.date(byAdding: .day, value: $0, to: start)! }
        let result = ContextAnalysisEngine().analyze(dataset: dataset, recordedCycleStarts: starts,
                                                     calendar: AnalyticsTestDates.calendar)
        let menstrual = try XCTUnwrap(result.phaseSummaries.first { $0.phase == .menstrual })
        XCTAssertEqual(menstrual.cycleCount, 3)
        XCTAssertEqual(menstrual.observationCount, 15)
        XCTAssertGreaterThan(menstrual.differenceFromPersonalMean, 0)

        let incomplete = ContextAnalysisEngine().analyze(dataset: dataset, recordedCycleStarts: [starts[0]],
                                                         calendar: AnalyticsTestDates.calendar)
        XCTAssertTrue(incomplete.phaseSummaries.isEmpty)
    }

    func testIrregularCyclesAreNotAssignedAndFlareUsesExplicitGroups() throws {
        let start = AnalyticsTestDates.date(2026, 2, 1)
        let starts = [0, 10, 70].map { AnalyticsTestDates.calendar.date(byAdding: .day, value: $0, to: start)! }
        let flareValues = (1...40).map { ($0, MetricObservedValue.boolean($0 <= 5)) }
        let energyValues = (1...40).map { ($0, MetricObservedValue.number($0 <= 5 ? 8 : 3)) }
        let dataset = phase5Dataset(definitions: [MetricCatalog.flareDay, MetricCatalog.energyLevel], dayCount: 40, start: start,
            values: [MetricCatalog.flareDay.id: flareValues, MetricCatalog.energyLevel.id: energyValues])
        let result = ContextAnalysisEngine().analyze(dataset: dataset, recordedCycleStarts: starts,
                                                     calendar: AnalyticsTestDates.calendar)
        XCTAssertTrue(result.phaseSummaries.isEmpty)
        let flare = try XCTUnwrap(result.flareComparisons.first { $0.metricID == MetricCatalog.energyLevel.id })
        XCTAssertEqual(flare.flareDayCount, 5)
        XCTAssertEqual(flare.nonFlareDayCount, 35)
        XCTAssertEqual(flare.difference, 5, accuracy: 1e-9)
    }
}

final class PersonalBaselineEngineTests: XCTestCase {
    func testRobustBaselineIgnoresOutlierAndDetectsRecentShift() throws {
        let stable = (1...28).map { day in (day, MetricObservedValue.number(day == 10 ? 100 : 5)) }
            + (29...35).map { ($0, MetricObservedValue.number(5)) }
        let stableBaseline = try XCTUnwrap(baseline(values: stable))
        XCTAssertEqual(stableBaseline.center, 5, accuracy: 1e-9)
        XCTAssertEqual(stableBaseline.position, .typical)

        let shifted = (1...28).map { ($0, MetricObservedValue.number(5)) }
            + (29...35).map { ($0, MetricObservedValue.number(9)) }
        let shiftedBaseline = try XCTUnwrap(baseline(values: shifted))
        XCTAssertEqual(shiftedBaseline.position, .above)
        XCTAssertEqual(shiftedBaseline.difference, 4, accuracy: 1e-9)
    }

    func testSparseHistoryDefinitionChangeAndLongGapQualifyOutput() throws {
        XCTAssertNil(baseline(values: (1...20).map { ($0, .number(5)) }))

        let start = AnalyticsTestDates.date(2026, 1, 1)
        let gapped = (1...28).map { ($0, MetricObservedValue.number(5)) }
            + (70...76).map { ($0, MetricObservedValue.number(5)) }
        let observations = baselineObservations(values: gapped, start: start)
        let result = try XCTUnwrap(PersonalBaselineEngine().build(definition: MetricCatalog.energyLevel,
                                                                  observations: observations))
        XCTAssertTrue(result.isQualifiedByGap)
        let changed = AnalyticsTestDates.calendar.date(byAdding: .day, value: 60, to: start)!
        XCTAssertNil(PersonalBaselineEngine().build(definition: MetricCatalog.energyLevel,
                                                    observations: observations, definitionChangedAt: changed))
    }

    private func baseline(values: [(Int, MetricObservedValue)]) -> PersonalBaseline? {
        PersonalBaselineEngine().build(definition: MetricCatalog.energyLevel,
                                       observations: baselineObservations(values: values, start: AnalyticsTestDates.date(2026, 1, 1)))
    }

    private func baselineObservations(values: [(Int, MetricObservedValue)], start: Date) -> [MetricObservation] {
        values.map { day, value in
            let date = AnalyticsTestDates.calendar.date(byAdding: .day, value: day - 1, to: start)!
            return MetricObservation(metricID: MetricCatalog.energyLevel.id, timestamp: date, day: date,
                state: .observed(value), source: MetricSourceReference(kind: .dailyLog, recordID: "baseline-\(day)"))
        }
    }
}

final class AdvancedInsightPersistenceTests: XCTestCase {
    func testFeedbackAndHypothesesRoundTripWithoutAnalyticsRevision() throws {
        let database = try TestDatabaseManager()
        let repo = AdvancedInsightRepo(databaseManager: database)
        var feedback = try repo.saveFeedback(InsightFeedback(insightID: "finding-a", rating: .useful))
        feedback.isSaved = true
        feedback.dismissedUntil = AnalyticsTestDates.date(2026, 8, 1)
        feedback = try repo.saveFeedback(feedback)
        XCTAssertEqual(try repo.feedback(for: "finding-a")?.feedbackRating, .useful)
        XCTAssertEqual(try repo.feedback(for: "finding-a")?.isSaved, true)
        XCTAssertEqual(try repo.feedback(for: "finding-a")?.dismissedUntil, feedback.dismissedUntil)
        XCTAssertTrue(feedback.isDismissed(at: AnalyticsTestDates.date(2026, 7, 18)))
        XCTAssertFalse(feedback.isDismissed(at: AnalyticsTestDates.date(2026, 8, 2)))

        var hypothesis = try repo.saveHypothesis(SavedHypothesis(title: "Water and pain",
            factorMetricID: MetricCatalog.hydration.id.rawValue, outcomeMetricID: MetricCatalog.painLevel.id.rawValue,
            notes: "Track consistently", reviewIntervalDays: 10))
        hypothesis = try XCTUnwrap(repo.fetchHypotheses().first)
        try repo.markHypothesisReviewed(id: try XCTUnwrap(hypothesis.id), at: AnalyticsTestDates.date(2026, 7, 18))
        XCTAssertNotNil(try repo.fetchHypotheses().first?.lastReviewedAt)
        try repo.deleteHypothesis(id: hypothesis.id!)
        XCTAssertTrue(try repo.fetchHypotheses().isEmpty)
    }
}

private func discoveryDefinition(_ id: MetricID) -> MetricDefinition {
    MetricDefinition(id: id, displayName: id.rawValue, description: "Synthetic numeric metric",
        category: .coreHealth, source: .dailyLog(field: "syntheticNumeric"), measurementLevel: .continuous, unit: .score,
        domain: .unrestricted, directionality: .neutral,
        aggregation: MetricAggregationPolicy(daily: .average, weekly: .average, monthly: .average),
        unrecordedDayPolicy: .missing, supportedAnalyses: [.relationship],
        recommendedVisualizations: [.line])
}

private func phase5Dataset(definitions: [MetricDefinition], dayCount: Int,
                           start: Date = AnalyticsTestDates.date(2026, 1, 1),
                           values: [MetricID: [(Int, MetricObservedValue)]]) -> AnalyticsDataset {
    let calendar = AnalyticsTestDates.calendar
    let end = calendar.date(byAdding: .day, value: dayCount, to: start)!
    let interval = DateInterval(start: start, end: end)
    var observations: [MetricObservation] = []
    for definition in definitions {
        for (index, value) in values[definition.id] ?? [] {
            let date = calendar.date(byAdding: .day, value: index - 1, to: start)!
            observations.append(MetricObservation(metricID: definition.id, timestamp: date, day: date,
                state: .observed(value), source: MetricSourceReference(kind: .dailyLog,
                    recordID: "\(definition.id.rawValue)-\(index)")))
        }
    }
    let coverage = Dictionary(uniqueKeysWithValues: definitions.map { definition in
        let matching = observations.filter { $0.metricID == definition.id }
        let sourceDays = Set(matching.map { calendar.startOfDay(for: $0.day) }).count
        return (definition.id, MetricCoverage(metricID: definition.id, interval: interval,
            possibleDayCount: dayCount, sourceDayCount: sourceDays, observedCount: matching.count,
            missingCount: max(0, dayCount - sourceDays), explicitNoneCount: 0, notApplicableCount: 0,
            firstObservation: matching.map(\.timestamp).min(), lastObservation: matching.map(\.timestamp).max()))
    })
    return AnalyticsDataset(interval: interval, definitions: definitions, observations: observations,
        rawEvents: [], coverage: coverage, metricAliases: [:],
        diagnostics: AnalyticsQueryDiagnostics(databaseReadCount: 0, statementCount: 0))
}
