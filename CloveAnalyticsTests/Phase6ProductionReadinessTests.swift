import XCTest
import GRDB
@testable import Clove

final class AnalyticsPerformanceBudgetTests: XCTestCase {
    func testTenYearRepositoryRefreshStaysWithinDashboardBudget() throws {
        let calendar = AnalyticsTestDates.calendar
        let start = AnalyticsTestDates.date(2016, 1, 1)
        let dayCount = 3_653
        let end = calendar.date(byAdding: .day, value: dayCount, to: start)!
        let logs = (0..<dayCount).map { day -> DailyLog in
            let date = calendar.date(byAdding: .day, value: day, to: start)!
            return DailyLog(date: date, mood: day % 11, painLevel: (day * 3) % 11,
                            energyLevel: (day * 7) % 11, waterIntake: (day % 8) * 8)
        }
        let repository = DefaultAnalyticsRepository(sourceLoader: Phase6SnapshotLoader(logs: logs),
            calendar: calendar, timeZone: AnalyticsTestDates.utc)
        let started = CFAbsoluteTimeGetCurrent()
        let dataset = try repository.load(AnalyticsRequest(interval: DateInterval(start: start, end: end)))
        let duration = CFAbsoluteTimeGetCurrent() - started

        XCTAssertLessThan(duration, AnalyticsPerformanceBudgets.maximumDashboardRefreshSeconds)
        XCTAssertEqual(dataset.diagnostics.databaseReadCount, 1)
        XCTAssertLessThanOrEqual(dataset.diagnostics.statementCount,
                                 AnalyticsPerformanceBudgets.maximumRepositoryStatements)
    }

    func testTenYearDatasetLookupAndChartDensityStayBounded() {
        let calendar = AnalyticsTestDates.calendar
        let start = AnalyticsTestDates.date(2016, 1, 1)
        let dayCount = 3_653
        let end = calendar.date(byAdding: .day, value: dayCount, to: start)!
        let definitions = [MetricCatalog.mood, MetricCatalog.painLevel, MetricCatalog.energyLevel,
                           MetricCatalog.hydration, MetricCatalog.flareDay]
        var observations: [MetricObservation] = []
        observations.reserveCapacity(dayCount * definitions.count)
        for (metricIndex, definition) in definitions.enumerated() {
            for day in 0..<dayCount {
                let date = calendar.date(byAdding: .day, value: day, to: start)!
                observations.append(MetricObservation(metricID: definition.id, timestamp: date, day: date,
                    state: .observed(.number(Double((day + metricIndex) % 10))),
                    source: MetricSourceReference(kind: .dailyLog, recordID: "fixture-\(metricIndex)-\(day)")))
            }
        }
        let interval = DateInterval(start: start, end: end)
        let coverage = Dictionary(uniqueKeysWithValues: definitions.map {
            ($0.id, MetricCoverage(metricID: $0.id, interval: interval, possibleDayCount: dayCount,
                sourceDayCount: dayCount, observedCount: dayCount, missingCount: 0, explicitNoneCount: 0,
                notApplicableCount: 0, firstObservation: start, lastObservation: end))
        })
        let dataset = AnalyticsDataset(interval: interval, definitions: definitions, observations: observations,
            rawEvents: [], coverage: coverage, metricAliases: [:],
            diagnostics: AnalyticsQueryDiagnostics(databaseReadCount: 1,
                statementCount: AnalyticsPerformanceBudgets.maximumRepositoryStatements))

        let lookupStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<500 { XCTAssertEqual(dataset.observations(for: MetricCatalog.hydration.id).count, dayCount) }
        let lookupDuration = CFAbsoluteTimeGetCurrent() - lookupStart
        XCTAssertLessThan(lookupDuration, AnalyticsPerformanceBudgets.maximumIndexedLookupSeconds)

        let result = AnalyticsChartPipeline(calendar: calendar).build(
            definition: MetricCatalog.hydration, dataset: dataset, granularity: .monthly)
        XCTAssertLessThanOrEqual(result.points.count, AnalyticsPerformanceBudgets.maximumLongRangeChartPoints)
    }

    func testDiscoveryProductionBudgetMatchesDocumentedLimit() {
        XCTAssertEqual(DiscoveryConfiguration().maximumTests,
                       AnalyticsPerformanceBudgets.maximumAutomaticDiscoveryTests)
    }
}

@MainActor
final class AnalyticsRolloutCoordinatorTests: XCTestCase {
    func testFreshInstallUpgradeRollbackAndRetryPreserveRecords() throws {
        let name = "AnalyticsRolloutCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let database = try TestDatabaseManager()
        try database.write { db in try DailyLog(date: AnalyticsTestDates.date(2026, 7, 1), mood: 7).insert(db) }

        let fresh = AnalyticsRolloutCoordinator(defaults: defaults)
        XCTAssertFalse(fresh.snapshot.isUpgrade)
        XCTAssertTrue(fresh.prepareDatabase(database))
        XCTAssertEqual(fresh.snapshot.state, .ready)
        fresh.unifiedAnalyticsEnabled = false
        fresh.unifiedAnalyticsEnabled = true
        XCTAssertEqual(try database.read { db in try DailyLog.fetchCount(db) }, 1)

        let upgrade = AnalyticsRolloutCoordinator(defaults: defaults)
        XCTAssertTrue(upgrade.snapshot.isUpgrade)
        XCTAssertEqual(upgrade.snapshot.state, .ready)

        let retry = FailOnceDatabaseManager()
        XCTAssertFalse(upgrade.prepareDatabase(retry))
        XCTAssertEqual(upgrade.snapshot.state, .failed)
        XCTAssertTrue(upgrade.prepareDatabase(retry))
        XCTAssertEqual(upgrade.snapshot.state, .ready)
    }

    func testInterruptedMigrationBecomesRecoverablePendingState() throws {
        let name = "AnalyticsRolloutInterrupted.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("migrating", forKey: "analyticsMigrationState.v1")
        let coordinator = AnalyticsRolloutCoordinator(defaults: defaults)
        XCTAssertEqual(coordinator.snapshot.state, .pending)
        XCTAssertTrue(coordinator.snapshot.recoveredInterruptedAttempt)
    }
}

final class AnalyticsDiagnosticsPrivacyTests: XCTestCase {
    func testTypedPayloadContainsOnlyAllowedAggregateFields() throws {
        let counter = AnalyticsDiagnosticCounter(area: .insightsHome, outcome: .success,
            interaction: nil, performance: .under250ms, count: 4)
        XCTAssertTrue(AnalyticsDiagnosticSchema.isAllowed(counter))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(counter)) as? [String: Any])
        XCTAssertTrue(Set(object.keys).isDisjoint(with: AnalyticsDiagnosticSchema.prohibitedPayloadFields))
        XCTAssertEqual(Set(object.keys), ["area", "outcome", "performance", "count"])
    }

    func testOptOutClearsCountersAndTelemetryIsNeverRequired() throws {
        let name = "AnalyticsDiagnosticsPrivacyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = AnalyticsDiagnosticsRecorder(defaults: defaults)
        recorder.recordLoad(.discovery, outcome: .success, duration: 0.2)
        XCTAssertEqual(recorder.counters().first?.count, 1)
        recorder.isEnabled = false
        XCTAssertTrue(recorder.counters().isEmpty)
        recorder.recordInteraction(.saveFinding, area: .discovery)
        XCTAssertTrue(recorder.counters().isEmpty)
    }
}

private final class FailOnceDatabaseManager: DatabaseManaging {
    private var shouldFail = true
    func setupDatabase() throws {
        if shouldFail { shouldFail = false; throw DatabaseError.notSetup }
    }
    func resetDatabase() throws {}
    func read<T>(_ block: (Database) throws -> T) throws -> T { throw DatabaseError.notSetup }
    func write(_ block: (Database) throws -> Void) throws { throw DatabaseError.notSetup }
    func writeReturning<T>(_ block: (Database) throws -> T) throws -> T { throw DatabaseError.notSetup }
}

private struct Phase6SnapshotLoader: AnalyticsSourceLoading {
    let logs: [DailyLog]
    func load(in interval: DateInterval) throws -> AnalyticsSourceSnapshot {
        AnalyticsSourceSnapshot(logs: logs, foodEntries: [], activityEntries: [], bowelMovements: [],
            cycleEntries: [], trackedSymptoms: [], trackedMedications: [], dynamicIdentities: [], metricAliases: [],
            diagnostics: AnalyticsQueryDiagnostics(databaseReadCount: 1,
                statementCount: AnalyticsPerformanceBudgets.maximumRepositoryStatements))
    }
}
