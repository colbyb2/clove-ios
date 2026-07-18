import XCTest
@testable import Clove

final class PairAlignmentEngineTests: XCTestCase {
    func testSparseAlignmentPreservesMissingAndReportsCoverage() throws {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 7, 1), end: AnalyticsTestDates.date(2026, 7, 6))
        let dataset = relationshipDataset(
            definitions: [MetricCatalog.hydration, MetricCatalog.painLevel], interval: interval,
            values: [
                MetricCatalog.hydration.id: [(1, .number(10)), (2, .number(0)), (4, .number(30))],
                MetricCatalog.painLevel.id: [(2, .number(5)), (3, .number(6)), (4, .number(7))]
            ]
        )
        let result = PairAlignmentEngine(calendar: AnalyticsTestDates.calendar, timeZone: AnalyticsTestDates.utc)
            .align(factor: MetricCatalog.hydration, outcome: MetricCatalog.painLevel, dataset: dataset)

        XCTAssertEqual(result.pairs.count, 2)
        XCTAssertEqual(result.pairs.map { $0.factor.numeric! }, [0, 30])
        XCTAssertEqual(result.coverage.eligibleDayCount, 5)
        XCTAssertEqual(result.coverage.factorObservedDayCount, 3)
        XCTAssertEqual(result.coverage.outcomeObservedDayCount, 3)
        XCTAssertEqual(result.coverage.excludedDayCount, 3)
    }

    func testPositiveLagMeansFactorPrecedesOutcome() throws {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 7, 1), end: AnalyticsTestDates.date(2026, 7, 8))
        let dataset = relationshipDataset(definitions: [MetricCatalog.hydration, MetricCatalog.painLevel], interval: interval, values: [
            MetricCatalog.hydration.id: [(1, .number(20)), (2, .number(40))],
            MetricCatalog.painLevel.id: [(3, .number(2)), (4, .number(4))]
        ])
        let result = PairAlignmentEngine(calendar: AnalyticsTestDates.calendar, timeZone: AnalyticsTestDates.utc)
            .align(factor: MetricCatalog.hydration, outcome: MetricCatalog.painLevel, dataset: dataset, lagDays: 2)
        XCTAssertEqual(result.pairs.count, 2)
        XCTAssertEqual(AnalyticsTestDates.calendar.dateComponents([.day], from: result.pairs[0].factorDay, to: result.pairs[0].outcomeDay).day, 2)
    }

    func testDSTDaysUseCalendarKeysRatherThanTwentyFourHourOffsets() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        let start = AnalyticsTestDates.date(2026, 3, 7, timeZone: zone)
        let interval = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 5, to: start)!)
        let dataset = relationshipDataset(definitions: [MetricCatalog.hydration, MetricCatalog.painLevel], interval: interval, calendar: calendar, values: [
            MetricCatalog.hydration.id: [(1, .number(1)), (2, .number(2)), (3, .number(3))],
            MetricCatalog.painLevel.id: [(2, .number(1)), (3, .number(2)), (4, .number(3))]
        ])
        let result = PairAlignmentEngine(calendar: calendar, timeZone: zone)
            .align(factor: MetricCatalog.hydration, outcome: MetricCatalog.painLevel, dataset: dataset, lagDays: 1)
        XCTAssertEqual(result.pairs.count, 3)
    }
}

final class RelationshipStatisticsEngineTests: XCTestCase {
    func testMethodSelectionUsesMeasurementSemantics() {
        let selector = RelationshipMethodSelector()
        XCTAssertEqual(selector.select(factor: MetricCatalog.hydration, outcome: MetricCatalog.mealCount), .pearson)
        XCTAssertEqual(selector.select(factor: MetricCatalog.painLevel, outcome: MetricCatalog.mood), .spearman)
        XCTAssertEqual(selector.select(factor: MetricCatalog.flareDay, outcome: MetricCatalog.hydration), .pointBiserial)
        XCTAssertEqual(selector.select(factor: MetricCatalog.flareDay, outcome: MetricCatalog.flareDay), .phi)
        XCTAssertEqual(selector.select(factor: MetricCatalog.weather, outcome: categoricalDefinition(id: "category:two")), .cramersV)
        XCTAssertEqual(selector.select(factor: MetricCatalog.weather, outcome: MetricCatalog.hydration), .correlationRatio)
    }

    func testPearsonMatchesPublishedReferenceAndPValueIsNotBucketed() throws {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 1, 1), end: AnalyticsTestDates.date(2026, 2, 1))
        let x = [43.0, 21, 25, 42, 57, 59]
        let y = [99.0, 65, 79, 75, 87, 81]
        let repeatedX = Array(repeating: x, count: 3).flatMap { $0 }
        let repeatedY = Array(repeating: y, count: 3).flatMap { $0 }
        let dataset = relationshipDataset(definitions: [MetricCatalog.hydration, MetricCatalog.mealCount], interval: interval, values: [
            MetricCatalog.hydration.id: repeatedX.enumerated().map { ($0.offset + 1, .number($0.element)) },
            MetricCatalog.mealCount.id: repeatedY.enumerated().map { ($0.offset + 1, .number($0.element)) }
        ])
        let alignment = PairAlignmentEngine(calendar: AnalyticsTestDates.calendar, timeZone: AnalyticsTestDates.utc)
            .align(factor: MetricCatalog.hydration, outcome: MetricCatalog.mealCount, dataset: dataset)
        let estimate = RelationshipStatisticsEngine().estimate(alignment: alignment, factor: MetricCatalog.hydration, outcome: MetricCatalog.mealCount)
        XCTAssertEqual(try XCTUnwrap(estimate.effect), 0.5298089019, accuracy: 1e-8)
        XCTAssertNotEqual(estimate.pValue, 0.05)
        XCTAssertNotNil(estimate.confidenceInterval)
    }

    func testOrdinalUsesSpearmanAndConstantSamplesReturnLimitation() {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 1, 1), end: AnalyticsTestDates.date(2026, 2, 1))
        let values = (1...14).map { ($0, MetricObservedValue.number(Double($0))) }
        let reverse = (1...14).map { ($0, MetricObservedValue.number(Double(15 - $0))) }
        let dataset = relationshipDataset(definitions: [MetricCatalog.painLevel, MetricCatalog.mood], interval: interval, values: [MetricCatalog.painLevel.id: values, MetricCatalog.mood.id: reverse])
        let alignment = PairAlignmentEngine(calendar: AnalyticsTestDates.calendar, timeZone: AnalyticsTestDates.utc).align(factor: MetricCatalog.painLevel, outcome: MetricCatalog.mood, dataset: dataset)
        let estimate = RelationshipStatisticsEngine().estimate(alignment: alignment, factor: MetricCatalog.painLevel, outcome: MetricCatalog.mood)
        XCTAssertEqual(estimate.method, .spearman)
        XCTAssertEqual(estimate.effect ?? 0, -1, accuracy: 1e-12)

        let constantData = relationshipDataset(definitions: [MetricCatalog.hydration, MetricCatalog.mealCount], interval: interval, values: [
            MetricCatalog.hydration.id: (1...14).map { ($0, .number(5)) },
            MetricCatalog.mealCount.id: (1...14).map { ($0, .number(Double($0))) }
        ])
        let constantAlignment = PairAlignmentEngine(calendar: AnalyticsTestDates.calendar, timeZone: AnalyticsTestDates.utc).align(factor: MetricCatalog.hydration, outcome: MetricCatalog.mealCount, dataset: constantData)
        let constant = RelationshipStatisticsEngine().estimate(alignment: constantAlignment, factor: MetricCatalog.hydration, outcome: MetricCatalog.mealCount)
        XCTAssertNil(constant.effect)
        XCTAssertTrue(constant.limitations.contains { $0.contains("did not vary") })
    }

    func testLagProfileFindsKnownDelayedSignal() {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 1, 1), end: AnalyticsTestDates.date(2026, 3, 1))
        let factor = (1...35).map { ($0, MetricObservedValue.number(Double(($0 * 7) % 19))) }
        let outcome = factor.map { ($0.0 + 3, $0.1) }
        let dataset = relationshipDataset(definitions: [MetricCatalog.hydration, MetricCatalog.mealCount], interval: interval, values: [MetricCatalog.hydration.id: factor, MetricCatalog.mealCount.id: outcome])
        let profile = LaggedRelationshipEngine().analyze(factor: MetricCatalog.hydration, outcome: MetricCatalog.mealCount, dataset: dataset, normalizer: PairAlignmentEngine(calendar: AnalyticsTestDates.calendar, timeZone: AnalyticsTestDates.utc))
        XCTAssertEqual(profile.bestSupported?.lagDays, 3)
        XCTAssertTrue(profile.limitations.contains { $0.contains("explored") })
    }
}

final class EventOutcomeAndSavedAnalysisTests: XCTestCase {
    func testEventOutcomeCollapsesOverlapsAndReportsGroups() throws {
        let event = MetricCatalog.activityOccurrence(id: "activity:test", name: "Walk")
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 1, 1), end: AnalyticsTestDates.date(2026, 1, 21))
        var dataset = relationshipDataset(definitions: [event, MetricCatalog.painLevel], interval: interval, values: [
            MetricCatalog.painLevel.id: (1...20).map { ($0, .number([3, 7, 12].contains($0) ? 8 : 2)) }
        ])
        dataset = AnalyticsDataset(interval: dataset.interval, definitions: dataset.definitions, observations: dataset.observations,
            rawEvents: [3, 3, 7, 12].enumerated().map { index, day in
                let date = AnalyticsTestDates.calendar.date(byAdding: .day, value: day - 1, to: interval.start)!
                return MetricRawEvent(metricID: event.id, timestamp: date, day: date, source: MetricSourceReference(kind: .activityEntry, recordID: "e\(index)"))
            }, coverage: dataset.coverage, metricAliases: [:], diagnostics: dataset.diagnostics)
        let result = EventOutcomeEngine(calendar: AnalyticsTestDates.calendar, timeZone: AnalyticsTestDates.utc).analyze(event: event, outcome: MetricCatalog.painLevel, dataset: dataset, outcomeOffsetDays: 0)
        XCTAssertEqual(result.exposedCount, 3)
        XCTAssertEqual(result.controlCount, 17)
        XCTAssertEqual(result.meanDifference ?? 0, 6, accuracy: 1e-9)
    }

    func testSavedAnalysisPersistsRenamesAndDeletes() throws {
        let database = try TestDatabaseManager()
        let repo = SavedAnalysisRepo(databaseManager: database)
        var saved = try repo.save(SavedAnalysis(title: "Hydration and pain", factorMetricID: "hydration", outcomeMetricID: "pain_level", rangePolicy: "30D", method: "spearman"))
        saved = try XCTUnwrap(repo.fetchAll().first)
        XCTAssertNotNil(saved.id)
        try repo.rename(id: saved.id!, title: "Water vs pain")
        XCTAssertEqual(try repo.fetchAll().first?.title, "Water vs pain")
        try repo.delete(id: saved.id!)
        XCTAssertTrue(try repo.fetchAll().isEmpty)
    }
}

private func categoricalDefinition(id: MetricID) -> MetricDefinition {
    MetricDefinition(id: id, displayName: "Category", description: "Fixture category", category: .environmental,
                     source: .dailyLog(field: "syntheticCategory"), measurementLevel: .categorical, unit: .category,
                     domain: .categories(["A", "B"]), directionality: .neutral,
                     aggregation: MetricAggregationPolicy(daily: .mode, weekly: .distribution, monthly: .distribution),
                     unrecordedDayPolicy: .missing, supportedAnalyses: [.relationship],
                     recommendedVisualizations: [.distribution])
}

private func relationshipDataset(definitions: [MetricDefinition], interval: DateInterval,
                                 calendar: Calendar = AnalyticsTestDates.calendar,
                                 values: [MetricID: [(Int, MetricObservedValue)]]) -> AnalyticsDataset {
    var observations: [MetricObservation] = []
    for definition in definitions {
        for (index, item) in (values[definition.id] ?? []).enumerated() {
            let date = calendar.date(byAdding: .day, value: item.0 - 1, to: interval.start)!
            observations.append(MetricObservation(metricID: definition.id, timestamp: date, day: date,
                                                   state: .observed(item.1),
                                                   source: MetricSourceReference(kind: .dailyLog, recordID: "\(definition.id)-\(index)")))
        }
    }
    let days = max(1, calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
    let coverage = Dictionary(uniqueKeysWithValues: definitions.map { definition in
        let metricValues = observations.filter { $0.metricID == definition.id }
        return (definition.id, MetricCoverage(metricID: definition.id, interval: interval, possibleDayCount: days,
            sourceDayCount: metricValues.count, observedCount: metricValues.count, missingCount: 0, explicitNoneCount: 0,
            notApplicableCount: 0, firstObservation: metricValues.map(\.timestamp).min(), lastObservation: metricValues.map(\.timestamp).max()))
    })
    return AnalyticsDataset(interval: interval, definitions: definitions, observations: observations, rawEvents: [], coverage: coverage,
                            metricAliases: [:], diagnostics: AnalyticsQueryDiagnostics(databaseReadCount: 0, statementCount: 0))
}
