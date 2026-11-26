import Foundation
import GRDB
import XCTest
@testable import Clove

final class SleepTrackingTests: XCTestCase {
    private var utc: TimeZone { TimeZone(secondsFromGMT: 0)! }
    private func day(_ key: String, zone: TimeZone? = nil) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone ?? utc
        return LocalDayKey.date(from: key, calendar: calendar)!
    }
    private func sleep(_ key: String = "2026-11-24", bed: Int = 22, wake: Int = 7, zone: TimeZone? = nil) throws -> SleepPeriod {
        try SleepPeriod.fromTimes(wakeDay: day(key, zone: zone), bedtimeHour: bed, bedtimeMinute: 30,
                                  wakeHour: wake, wakeMinute: 0, timeZone: zone ?? utc)
    }

    func testOvernightAndDaytimeSleepAreAttributedToWakeDay() throws {
        let night = try sleep()
        XCTAssertEqual(night.durationMinutes, 510)
        XCTAssertEqual(night.durationText, "8h 30m")
        XCTAssertEqual(LocalDayKey.make(for: night.bedtime, calendar: AnalyticsTestDates.calendar), "2026-11-23")
        try night.validate(dayKey: "2026-11-24")
        XCTAssertThrowsError(try night.validate(dayKey: "2026-11-23"))
        let afterMidnight = try sleep(bed: 1)
        XCTAssertEqual(afterMidnight.durationMinutes, 330)
        let daytime = try sleep(bed: 9, wake: 17)
        XCTAssertEqual(daytime.durationMinutes, 450)
        XCTAssertEqual(LocalDayKey.make(for: daytime.bedtime, calendar: AnalyticsTestDates.calendar), "2026-11-24")
    }

    func testClockChangesUseElapsedTimeAndRejectNonexistentTimes() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        XCTAssertEqual(try sleep("2026-03-08", zone: zone).durationMinutes, 450)
        XCTAssertEqual(try sleep("2026-11-01", zone: zone).durationMinutes, 570)
        XCTAssertThrowsError(try SleepPeriod.fromTimes(wakeDay: day("2026-03-08", zone: zone),
            bedtimeHour: 2, bedtimeMinute: 30, wakeHour: 7, wakeMinute: 0, timeZone: zone))
        XCTAssertThrowsError(try SleepPeriod.fromTimes(wakeDay: day("2026-11-24"),
            bedtimeHour: 7, bedtimeMinute: 0, wakeHour: 7, wakeMinute: 0, timeZone: utc))
    }

    func testSaveEditAndClearSleepPreserveOtherDailyData() throws {
        let db = try TestDatabaseManager()
        let repo = LogsRepo(databaseManager: db, calendar: AnalyticsTestDates.calendar)
        let date = day("2026-11-24")
        var log = DailyLog(date: date, mood: 6, notes: "Keep this note", sleep: try sleep())
        try repo.persistLog(log)
        log = try XCTUnwrap(repo.loadLog(for: date))
        XCTAssertEqual(log.sleep?.durationMinutes, 510)
        log.sleep = try sleep(bed: 23)
        try repo.persistLog(log)
        XCTAssertEqual(try repo.loadLog(for: date)?.sleep?.durationMinutes, 450)
        log.sleep = nil
        try repo.persistLog(log)
        let cleared = try XCTUnwrap(repo.loadLog(for: date))
        XCTAssertNil(cleared.sleepJSON)
        XCTAssertEqual(cleared.mood, 6)
        XCTAssertEqual(cleared.notes, "Keep this note")
        XCTAssertEqual(try repo.loadLogs().count, 1)
    }

    func testSleepOnlyDaysAppearInHistoryAndAnalyticsKeepMissingDaysMissing() throws {
        let db = try TestDatabaseManager()
        let repo = LogsRepo(databaseManager: db, calendar: AnalyticsTestDates.calendar)
        try repo.persistLog(DailyLog(date: day("2026-11-24"), sleep: try sleep()))
        try repo.persistLog(DailyLog(date: day("2026-11-25"), mood: 6))
        let summaries = try HistoryDaySummaryRepo(databaseManager: db, calendar: AnalyticsTestDates.calendar).loadDaySummaries()
        XCTAssertTrue(try XCTUnwrap(summaries[day("2026-11-24")]).hasAnyData)
        let analytics = DefaultAnalyticsRepository(sourceLoader: GRDBAnalyticsSourceLoader(databaseManager: db), timeZone: utc)
        let result = try analytics.load(AnalyticsRequest(interval: DateInterval(start: day("2026-11-24"), end: day("2026-11-27")),
                                                          metricIDs: [MetricCatalog.sleepDuration.id]))
        XCTAssertEqual(result.observations.filter { if case .observed = $0.state { return true }; return false }.count, 1)
        XCTAssertEqual(result.coverage[MetricCatalog.sleepDuration.id]?.sourceDayCount, 1)
        XCTAssertEqual(MetricCatalog.sleepDuration.unrecordedDayPolicy, .missing)
        XCTAssertEqual(MetricCatalog.sleepDuration.directionality, .neutral)
    }

    @MainActor
    func testTodaySleepIsNotRecordedOnOpenAndFlushesBeforeDateChange() throws {
        let logs = MockLogsRepository()
        var settings = UserSettings.blank
        settings.trackSleep = true
        let vm = TodayViewModel(logsRepository: logs, symptomsRepository: MockSymptomsRepository(),
            settingsRepository: MockUserSettingsRepository(settings: settings), medicationRepository: MockMedicationRepository(),
            bowelMovementRepository: MockBowelMovementRepository(), cycleRepository: MockCycleRepository(), toastManager: MockToastManager())
        let selected = day("2026-11-24").addingTimeInterval(12 * 3600)
        vm.loadLogData(for: selected)
        XCTAssertFalse(vm.hasPendingChanges)
        XCTAssertNil(logs.getLogForDate(selected))
        vm.logData.sleep = try sleep()
        vm.scheduleAutoSave(for: .sleep)
        XCTAssertTrue(vm.hasPendingChanges)
        vm.loadLogData(for: selected.addingTimeInterval(86400))
        XCTAssertEqual(logs.getLogForDate(selected)?.sleep?.durationMinutes, 510)
        XCTAssertNil(vm.logData.sleep)
    }

    func testSettingsLayoutAndLegacyJSONRemainCompatible() throws {
        var settings = UserSettings.blank
        settings.trackSleep = true
        XCTAssertTrue(settings.isSomeEnabled())
        let db = try TestDatabaseManager()
        let repo = UserSettingsRepo(databaseManager: db)
        XCTAssertTrue(repo.saveSettings(settings))
        XCTAssertTrue(try XCTUnwrap(repo.loadSettings()).trackSleep)
        settings.trackSleep = false
        XCTAssertTrue(repo.saveSettings(settings))
        XCTAssertFalse(try XCTUnwrap(repo.loadSettings()).trackSleep)
        let legacyJSON = try JSONEncoder().encode(DailyLog(date: day("2026-11-24"), mood: 7))
        XCTAssertFalse(String(decoding: legacyJSON, as: UTF8.self).contains("sleepJSON"))
        XCTAssertNil(try JSONDecoder().decode(DailyLog.self, from: legacyJSON).sleep)
        XCTAssertFalse(try JSONDecoder().decode(UserSettings.self, from: JSONEncoder().encode(UserSettings.blank)).trackSleep)
        var layout = TodayLayoutPreferences.default
        layout.order.removeAll { $0 == .sleep }
        layout.normalize()
        XCTAssertTrue(layout.items(customMetricIDs: []).contains(.module(.sleep)))
    }

    func testFullBackupRestoresExactIntervalAndTimeZone() throws {
        let db = try TestDatabaseManager()
        let suiteName = "SleepBackup-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = CloveArchiveManager(databaseManager: db, userDefaults: defaults, notificationProvider: { [] }, notificationRestorer: { _ in })
        let period = try sleep("2026-11-01", zone: TimeZone(identifier: "America/New_York"))
        try db.write { try DailyLog(date: period.wakeTime, dayKey: "2026-11-01", sleep: period).insert($0) }
        let file = try manager.createArchiveFile()
        defer { try? FileManager.default.removeItem(at: file) }
        try db.write { try $0.execute(sql: "DELETE FROM dailyLog") }
        _ = try manager.restoreArchive(from: file)
        XCTAssertEqual(try db.read { try DailyLog.fetchOne($0)?.sleep }, period)
    }

    func testCSVHasSeparateSleepColumnsAndDoesNotTreatThemAsSymptoms() throws {
        let csv = try DataManager.shared.generateCSVContent(logs: [DailyLog(date: day("2026-11-24"), sleep: try sleep())],
            categories: [.date, .sleep], selectedSymptoms: [])
        let lines = csv.components(separatedBy: "\n")
        XCTAssertTrue(lines[0].contains("Sleep Duration (min)"))
        XCTAssertTrue(lines[1].contains(",510,"))
        let headers = lines[0].components(separatedBy: ",")
        XCTAssertTrue(ImportValidator.extractSymptomColumns(from: headers).isEmpty)
        XCTAssertThrowsError(try ImportValidator.validateRowData(lines[1].components(separatedBy: ","), headers: headers, rowNumber: 1))
    }
}
