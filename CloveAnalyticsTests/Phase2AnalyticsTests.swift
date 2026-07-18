import XCTest
@testable import Clove

final class MetricAnalysisSummaryTests: XCTestCase {
    func testTypedSummariesDoNotForceOneGenericStatistic() throws {
        let interval = AnalyticsDateRangeFactory(calendar: AnalyticsTestDates.calendar).interval(for: .week, now: AnalyticsTestDates.date(2026, 7, 7))

        let numeric = dataset(definition: MetricCatalog.mood, interval: interval, values: [.number(2), .number(4), .number(6)])
        guard case .numeric(let mean, let median, _, _, let total)? = MetricAnalysisSummaryEngine().summarize(definition: MetricCatalog.mood, dataset: numeric).value else {
            return XCTFail("Expected numeric summary")
        }
        XCTAssertEqual(mean, 4, accuracy: 1e-9)
        XCTAssertEqual(median, 4, accuracy: 1e-9)
        XCTAssertNil(total)

        let continuous = dataset(definition: MetricCatalog.hydration, interval: interval, values: [.number(40), .number(60)])
        guard case .numeric(let hydrationMean, _, _, _, _)? = MetricAnalysisSummaryEngine().summarize(definition: MetricCatalog.hydration, dataset: continuous).value else {
            return XCTFail("Expected continuous summary")
        }
        XCTAssertEqual(hydrationMean, 50, accuracy: 1e-9)

        let count = dataset(definition: MetricCatalog.mealCount, interval: interval, values: [.number(2), .number(3)])
        guard case .numeric(_, _, _, _, let countTotal)? = MetricAnalysisSummaryEngine().summarize(definition: MetricCatalog.mealCount, dataset: count).value else {
            return XCTFail("Expected count summary")
        }
        XCTAssertEqual(countTotal, 5)

        let eventDefinition = MetricCatalog.activityOccurrence(id: "activity:fixture", name: "Walk")
        let event = dataset(definition: eventDefinition, interval: interval, values: [.number(1), .number(2)])
        guard case .event(let eventCount, let activeDays)? = MetricAnalysisSummaryEngine().summarize(definition: eventDefinition, dataset: event).value else {
            return XCTFail("Expected event summary")
        }
        XCTAssertEqual(eventCount, 3)
        XCTAssertEqual(activeDays, 2)

        let binary = dataset(definition: MetricCatalog.flareDay, interval: interval, values: [.boolean(true), .boolean(false), .boolean(true)])
        guard case .binary(let occurrences, let denominator, let rate)? = MetricAnalysisSummaryEngine().summarize(definition: MetricCatalog.flareDay, dataset: binary).value else {
            return XCTFail("Expected binary summary")
        }
        XCTAssertEqual(occurrences, 2)
        XCTAssertEqual(denominator, 3)
        XCTAssertEqual(rate, 200.0 / 3.0, accuracy: 1e-9)

        let categorical = dataset(definition: MetricCatalog.weather, interval: interval, values: [.category("Sunny"), .category("Rainy"), .category("Sunny")])
        guard case .categorical(let buckets, let mode)? = MetricAnalysisSummaryEngine().summarize(definition: MetricCatalog.weather, dataset: categorical).value else {
            return XCTFail("Expected categorical summary")
        }
        XCTAssertEqual(mode, "Sunny")
        XCTAssertEqual(buckets.first?.count, 2)

        let percentage = dataset(definition: MetricCatalog.medicationAdherence, interval: interval, values: [.ratio(numerator: 1, denominator: 1), .ratio(numerator: 1, denominator: 3)])
        guard case .percentage(let value, let numerator, let denominator)? = MetricAnalysisSummaryEngine().summarize(definition: MetricCatalog.medicationAdherence, dataset: percentage).value else {
            return XCTFail("Expected percentage summary")
        }
        XCTAssertEqual(value, 50, accuracy: 1e-9)
        XCTAssertEqual(numerator, 2)
        XCTAssertEqual(denominator, 4)
    }

    func testTrendUsesMinimumSamplePolicyAndDirectionality() throws {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 7, 1), end: AnalyticsTestDates.date(2026, 7, 9))
        let data = dataset(definition: MetricCatalog.painLevel, interval: interval, values: (1...7).map { .number(Double($0)) })
        let trend = try XCTUnwrap(MetricAnalysisSummaryEngine().summarize(definition: MetricCatalog.painLevel, dataset: data).trend)
        XCTAssertEqual(trend.direction, .increasing)
        XCTAssertEqual(trend.favorability, .unfavorable)
        XCTAssertEqual(trend.sampleCount, 7)
    }

    func testSparseAndZeroDenominatorProduceLimitations() {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 7, 1), end: AnalyticsTestDates.date(2026, 7, 8))
        let sparse = dataset(definition: MetricCatalog.medicationAdherence, interval: interval, values: [.ratio(numerator: 0, denominator: 0)])
        let result = MetricAnalysisSummaryEngine().summarize(definition: MetricCatalog.medicationAdherence, dataset: sparse)
        XCTAssertNil(result.value)
        XCTAssertTrue(result.limitations.contains { $0.contains("No observed values") })
        XCTAssertTrue(result.limitations.contains { $0.contains("Fewer than half") })
    }

    func testComparisonReportsBothCoverageValues() throws {
        let currentInterval = DateInterval(start: AnalyticsTestDates.date(2026, 7, 1), end: AnalyticsTestDates.date(2026, 7, 8))
        let previousInterval = DateInterval(start: AnalyticsTestDates.date(2026, 6, 24), end: AnalyticsTestDates.date(2026, 7, 1))
        let current = dataset(definition: MetricCatalog.hydration, interval: currentInterval, values: [.number(64), .number(72)])
        let previous = dataset(definition: MetricCatalog.hydration, interval: previousInterval, values: [.number(40)])
        let comparison = try XCTUnwrap(MetricAnalysisSummaryEngine().summarize(definition: MetricCatalog.hydration, dataset: current, previousDataset: previous).comparison)
        XCTAssertEqual(comparison.currentCoverage.sourceDayCount, 2)
        XCTAssertEqual(comparison.previousCoverage.sourceDayCount, 1)
        XCTAssertEqual(try XCTUnwrap(comparison.absoluteChange), 28, accuracy: 1e-9)
    }
}

final class AnalyticsChartPipelineTests: XCTestCase {
    func testMissingDailyObservationCreatesSeparateLineSegment() {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 7, 1), end: AnalyticsTestDates.date(2026, 7, 6))
        let values: [(Date, MetricObservedValue)] = [
            (AnalyticsTestDates.date(2026, 7, 1), .number(3)),
            (AnalyticsTestDates.date(2026, 7, 2), .number(4)),
            (AnalyticsTestDates.date(2026, 7, 4), .number(5))
        ]
        let data = dataset(definition: MetricCatalog.mood, interval: interval, datedValues: values)
        let result = AnalyticsChartPipeline(calendar: AnalyticsTestDates.calendar).build(definition: MetricCatalog.mood, dataset: data, granularity: .daily)
        XCTAssertEqual(result.points.map(\.segment), [0, 0, 1])
        XCTAssertEqual(result.family, .numericLine)
    }

    func testBinaryBucketsUseRateAndObservedDenominator() {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 7, 1), end: AnalyticsTestDates.date(2026, 7, 4))
        let data = dataset(definition: MetricCatalog.flareDay, interval: interval, values: [.boolean(true), .boolean(false), .boolean(true)])
        let result = AnalyticsChartPipeline(calendar: AnalyticsTestDates.calendar).build(definition: MetricCatalog.flareDay, dataset: data, granularity: .weekly)
        XCTAssertEqual(result.family, .binaryRate)
        XCTAssertEqual(result.points.first?.value ?? -1, 200.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(result.points.first?.denominator, 3)
    }

    func testCategoricalAndBristolMetricsUseDistributionCharts() {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 7, 1), end: AnalyticsTestDates.date(2026, 7, 4))
        let weather = dataset(definition: MetricCatalog.weather, interval: interval, values: [.category("Sunny"), .category("Rainy"), .category("Sunny")])
        let weatherResult = AnalyticsChartPipeline(calendar: AnalyticsTestDates.calendar).build(definition: MetricCatalog.weather, dataset: weather, granularity: .daily)
        XCTAssertEqual(weatherResult.family, .categoricalDistribution)
        XCTAssertEqual(weatherResult.categories.first(where: { $0.category == "Sunny" })?.count, 2)

        let bristol = dataset(definition: MetricCatalog.bristolStoolType, interval: interval, values: [.distribution([MetricDistributionBucket(value: "4", count: 2)])])
        let bristolResult = AnalyticsChartPipeline(calendar: AnalyticsTestDates.calendar).build(definition: MetricCatalog.bristolStoolType, dataset: bristol, granularity: .daily)
        XCTAssertEqual(bristolResult.family, .bristolDistribution)
        XCTAssertEqual(bristolResult.categories.first?.category, "Type 4")
        XCTAssertEqual(bristolResult.categories.first?.count, 2)
    }

    func testRecordedBowelDaysProduceVisibleBristolSummaryAndDistribution() throws {
        let database = try TestDatabaseManager()
        let dates = [
            AnalyticsTestDates.date(2026, 7, 2),
            AnalyticsTestDates.date(2026, 7, 8),
            AnalyticsTestDates.date(2026, 7, 14)
        ]
        try database.write { db in
            for (index, date) in dates.enumerated() {
                try BowelMovement(type: Double(index + 3), date: date).insert(db)
            }
        }
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 7, 1), end: AnalyticsTestDates.date(2026, 7, 31))
        let dataset = try DefaultAnalyticsRepository(
            sourceLoader: GRDBAnalyticsSourceLoader(databaseManager: database),
            calendar: AnalyticsTestDates.calendar,
            timeZone: AnalyticsTestDates.utc
        ).load(AnalyticsRequest(interval: interval, metricIDs: [MetricCatalog.bristolStoolType.id]))
        let result = AnalyticsChartPipeline(calendar: AnalyticsTestDates.calendar).build(
            definition: MetricCatalog.bristolStoolType,
            dataset: dataset,
            granularity: .daily
        )

        XCTAssertNotNil(result.summary.value)
        XCTAssertEqual(result.summary.coverage.observedCount, 3)
        XCTAssertEqual(result.categories.reduce(0) { $0 + $1.count }, 3)
        XCTAssertEqual(Set(result.categories.map(\.category)), ["Type 3", "Type 4", "Type 5"])
    }

    func testHydrationHasGoalSpecificFamily() {
        let interval = DateInterval(start: AnalyticsTestDates.date(2026, 7, 1), end: AnalyticsTestDates.date(2026, 7, 3))
        let data = dataset(definition: MetricCatalog.hydration, interval: interval, values: [.number(48), .number(64)])
        let result = AnalyticsChartPipeline(calendar: AnalyticsTestDates.calendar).build(definition: MetricCatalog.hydration, dataset: data, granularity: .daily)
        XCTAssertEqual(result.family, .hydrationProgress(goal: 64))
    }

    func testPreviousRangeIsCalendarSafeAcrossDSTAndLeapDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let factory = AnalyticsDateRangeFactory(calendar: calendar)
        let current = try XCTUnwrap(factory.custom(
            start: calendar.date(from: DateComponents(year: 2024, month: 3, day: 9))!,
            inclusiveEnd: calendar.date(from: DateComponents(year: 2024, month: 3, day: 11))!
        ))
        let previous = try XCTUnwrap(factory.previous(equalTo: current))
        XCTAssertEqual(previous.end, current.start)
        XCTAssertEqual(calendar.dateComponents([.day], from: previous.start, to: previous.end).day, 3)

        let leap = try XCTUnwrap(factory.custom(
            start: calendar.date(from: DateComponents(year: 2024, month: 2, day: 28))!,
            inclusiveEnd: calendar.date(from: DateComponents(year: 2024, month: 3, day: 1))!
        ))
        XCTAssertEqual(calendar.dateComponents([.day], from: leap.start, to: leap.end).day, 3)
    }
}

private func dataset(
    definition: MetricDefinition,
    interval: DateInterval,
    values: [MetricObservedValue]
) -> AnalyticsDataset {
    dataset(definition: definition, interval: interval, datedValues: values.enumerated().map {
        (AnalyticsTestDates.calendar.date(byAdding: .day, value: $0.offset, to: interval.start)!, $0.element)
    })
}

private func dataset(
    definition: MetricDefinition,
    interval: DateInterval,
    datedValues: [(Date, MetricObservedValue)]
) -> AnalyticsDataset {
    let observations = datedValues.enumerated().map { index, item in
        MetricObservation(
            metricID: definition.id,
            timestamp: item.0,
            day: item.0,
            state: .observed(item.1),
            source: MetricSourceReference(kind: .dailyLog, recordID: "fixture-\(index)")
        )
    }
    let coverage = MetricCoverage(
        metricID: definition.id,
        interval: interval,
        possibleDayCount: max(1, AnalyticsTestDates.calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1),
        sourceDayCount: Set(observations.map(\.day)).count,
        observedCount: observations.count,
        missingCount: 0,
        explicitNoneCount: 0,
        notApplicableCount: 0,
        firstObservation: observations.first?.timestamp,
        lastObservation: observations.last?.timestamp
    )
    return AnalyticsDataset(
        interval: interval,
        definitions: [definition],
        observations: observations,
        rawEvents: [],
        coverage: [definition.id: coverage],
        metricAliases: [:],
        diagnostics: AnalyticsQueryDiagnostics(databaseReadCount: 0, statementCount: 0)
    )
}
