import XCTest
import GRDB
@testable import Clove

final class CycleDayInsightsTests: XCTestCase {
    private let calendar = AnalyticsTestDates.calendar
    private func date(_ day: Int) -> Date { AnalyticsTestDates.date(2025, 1, day) }
    private var interval: DateInterval { DateInterval(start: date(1), end: date(20)) }

    private func observation(_ day: Int, _ number: Double) -> MetricObservation {
        MetricObservation(metricID: MetricCatalog.painLevel.id, timestamp: date(day), day: date(day),
                          state: .observed(.number(number)),
                          source: MetricSourceReference(kind: .dailyLog, recordID: "\(day)"))
    }
    private var starts: [Cycle] {
        [1, 5, 9].map { Cycle(date: date($0), flow: .medium, isStartOfCycle: true) }
    }

    @MainActor
    func testCycleInsightsFollowFeatureSettingEvenWithHistoricalEntries() {
        var settings = UserSettings.default
        settings.trackCycle = false
        let repository = MockUserSettingsRepository(settings: settings)
        let viewModel = InsightsHomeViewModel(settingsRepository: repository)
        viewModel.cycleEntries = starts
        viewModel.refreshCycleSettings()
        XCTAssertFalse(viewModel.isCycleEnabled)

        repository.settings?.trackCycle = true
        viewModel.refreshCycleSettings()
        XCTAssertTrue(viewModel.isCycleEnabled)

        repository.settings?.trackCycle = false
        viewModel.refreshCycleSettings()
        XCTAssertFalse(viewModel.isCycleEnabled)
        XCTAssertEqual(viewModel.cycleEntries.count, 3)
    }

    func testAlignsCompletedCyclesAndExcludesCurrentCycle() throws {
        let result = CycleDayAnalysisEngine().analyze(observations: [observation(1, 2), observation(5, 6), observation(9, 10)],
            entries: starts, interval: interval, calendar: calendar)
        XCTAssertEqual(result.completedCycleCount, 2)
        let day1 = try XCTUnwrap(result.points.first)
        XCTAssertEqual(day1.mean, 4)
        XCTAssertEqual(day1.observationCount, 2)
        XCTAssertNil(result.points[1].mean)
        XCTAssertEqual(result.points[1].observationCount, 0)
    }

    func testExplicitNoFlowIsDifferentFromSignsOnlyAndMissingDays() throws {
        let entries = starts + [
            Cycle(date: date(2), flow: .noFlow),
            Cycle(date: date(3), flow: .notRecorded, fertilitySigns: true, ovulation: true)
        ]
        let result = CycleDayAnalysisEngine().analyze(
            observations: [observation(1, 4), observation(2, 2), observation(3, 10), observation(4, 8)],
            entries: entries, interval: interval, calendar: calendar)
        XCTAssertEqual(result.flowGroups.first(where: { $0.hasFlow })?.mean, 4)
        XCTAssertEqual(result.flowGroups.first(where: { !$0.hasFlow })?.mean, 2)
        XCTAssertEqual(result.points[2].fertilityCount, 1)
        XCTAssertEqual(result.points[2].ovulationCount, 1)
        XCTAssertEqual(result.points[2].noFlowCount, 0)
        XCTAssertEqual(result.points[3].noFlowCount, 0)
    }

    func testPartialRangeUsesActualCycleDaysAndEditedStarts() throws {
        var edited = starts
        edited[1].date = date(6)
        let result = CycleDayAnalysisEngine().analyze(observations: [observation(7, 8)], entries: edited,
            interval: DateInterval(start: date(7), end: date(9)), calendar: calendar)
        XCTAssertEqual(result.completedCycleCount, 1)
        XCTAssertEqual(result.points.first?.day, 2)
        XCTAssertEqual(result.points.first?.mean, 8)
    }

    func testBinaryMeasurementsDisplayRecordedOccurrencePercent() {
        let result = CycleDayAnalysisEngine().analyze(observations: [observation(1, 0), observation(5, 1)],
            entries: starts, interval: interval, binary: true, calendar: calendar)
        XCTAssertEqual(result.points.first?.mean, 50)
    }

    func testCalendarDaysRemainAlignedAcrossDST() throws {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try XCTUnwrap(local.date(from: DateComponents(year: 2025, month: 3, day: 8)))
        let second = try XCTUnwrap(local.date(byAdding: .day, value: 3, to: start))
        let day2 = try XCTUnwrap(local.date(byAdding: .day, value: 2, to: start))
        let value = MetricObservation(metricID: MetricCatalog.painLevel.id, timestamp: day2, day: day2,
            state: .observed(.number(7)), source: MetricSourceReference(kind: .dailyLog, recordID: "DST"))
        let result = CycleDayAnalysisEngine().analyze(observations: [value],
            entries: [Cycle(date: start, flow: .medium, isStartOfCycle: true), Cycle(date: second, flow: .light, isStartOfCycle: true)],
            interval: DateInterval(start: start, end: second), calendar: local)
        XCTAssertEqual(result.points.count, 3)
        XCTAssertEqual(result.points[2].mean, 7)
    }

    func testMigrationPreservesOldFlowAndAllowsSignsOnlyRecords() throws {
        let oldMigrations = Array(Migrations.all.prefix { $0.identifier != CycleObservationsMigration().identifier })
        let database = try TestDatabaseManager(migrations: oldMigrations)
        try database.write { db in
            try db.execute(sql: "INSERT INTO cycle (date, flow, isStartOfCycle, hasCramps) VALUES (?, ?, 0, 0)",
                           arguments: [self.date(1), "heavy"])
        }
        try database.migrate(Migrations.all)
        let repo = CycleRepo(databaseManager: database)
        XCTAssertEqual(repo.getAllCycles().first?.flow, .heavy)
        XCTAssertNil(repo.getAllCycles().first?.fertilitySigns)
        XCTAssertTrue(repo.save([Cycle(date: date(2), flow: .notRecorded, fertilitySigns: true)]))
        let signs = try XCTUnwrap(repo.getCyclesForDate(date(2)).first)
        XCTAssertTrue(signs.fertilitySigns == true)
        XCTAssertEqual(signs.flow, .notRecorded)
        let restored = try JSONDecoder().decode(Cycle.self, from: JSONEncoder().encode(signs))
        XCTAssertEqual(restored.fertilitySigns, true)
        XCTAssertNil(restored.ovulation)
    }

    func testSignsOnlyDoNotCreateZeroFlowObservations() {
        let entries = [Cycle(id: 1, date: date(1), flow: .notRecorded, fertilitySigns: true), Cycle(id: 2, date: date(2), flow: .noFlow)]
        let batch = CycleObservationAdapter(normalizer: MetricDayNormalizer(calendar: calendar, timeZone: calendar.timeZone))
            .adapt(entries: entries, definitions: [MetricCatalog.flowLevel])
        XCTAssertEqual(batch.observations.count, 1)
        XCTAssertEqual(batch.observations.first?.state, .observed(.number(0)))
    }

    @MainActor
    func testCSVIncludesCycleOnlyDatesWithoutInventingFlareAnswers() throws {
        let csv = try DataManager.shared.generateCSVContent(logs: [], categories: [.date, .cycle, .flareDay],
            selectedSymptoms: [], cycleEntries: [Cycle(date: date(2), flow: .notRecorded, fertilitySigns: true)])
        let rows = csv.components(separatedBy: "\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows[0].contains("Cycle Flow,Period Started,Period Ended,Fertility Signs,Suspected Ovulation"))
        XCTAssertTrue(rows[1].hasSuffix(",,,,,Yes,"))
        XCTAssertFalse(rows[1].contains("No"))
    }

    func testLegacyJSONWithoutSignFieldsStillDecodes() throws {
        let data = try JSONEncoder().encode(Cycle(date: date(1), flow: .medium, isStartOfCycle: true))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "fertilitySigns")
        object.removeValue(forKey: "ovulation")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Cycle.self, from: oldData)
        XCTAssertEqual(decoded.flow, .medium)
        XCTAssertTrue(decoded.isStartOfCycle)
        XCTAssertNil(decoded.fertilitySigns)
        XCTAssertNil(decoded.ovulation)
    }

    func testNoFlowAndSignsDoNotExtendPeriodDuration() {
        let entries = [
            Cycle(date: date(1), flow: .heavy, isStartOfCycle: true),
            Cycle(date: date(2), flow: .light),
            Cycle(date: date(3), flow: .noFlow),
            Cycle(date: date(4), flow: .notRecorded, fertilitySigns: true),
            Cycle(date: date(29), flow: .heavy, isStartOfCycle: true)
        ]
        let analysis = CycleManager(cycleRepository: MockCycleRepository(), calendar: calendar).analyze(entries: entries)
        XCTAssertEqual(analysis.completedPeriodDurations, [2])
    }
}
