import XCTest
import GRDB
import CryptoKit
@testable import Clove

final class CustomMetricsTests: XCTestCase {
    private func date(_ day: Int) -> Date { AnalyticsTestDates.date(2026, 9, day, hour: 12) }
    private func definition(_ kind: CustomMetricKind = .number, name: String = "Sodium") -> CustomMetricDefinition {
        var value = CustomMetricDefinition(); value.name = name; value.kind = kind
        if kind == .number { value.unit = "mg"; value.precision = 1 }
        return value
    }
    private func value(_ definition: CustomMetricDefinition, day: Int = 10, number: Double = 0) -> CustomDailyValue {
        var value = CustomDailyValue(metricID: definition.id, dayKey: LocalDayKey.make(for: date(day)))
        switch definition.kind {
        case .number, .count, .rating: value.numberValue = number
        case .yesNo: value.booleanValue = number != 0
        case .duration: value.durationMinutes = Int(number)
        }
        return value
    }

    func testMigrationPreservesExistingSettingsAndDefaultsGroupOff() throws {
        let migrations = Array(Migrations.all.prefix { $0.identifier != CustomMetricsMigration().identifier })
        let db = try TestDatabaseManager(migrations: migrations)
        try db.write { try $0.execute(sql: "UPDATE userSettings SET trackPain = 1") }
        try db.migrate(Migrations.all)
        let settings = try XCTUnwrap(UserSettingsRepo(databaseManager: db).loadSettings())
        XCTAssertTrue(settings.trackPain)
        XCTAssertFalse(settings.trackCustomMetrics)
        let data = try JSONEncoder().encode(settings)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("trackCustomMetrics"))
    }

    func testCreationEnablesGroupAndTogglingOffReallyPersistsFalse() throws {
        let db = try TestDatabaseManager()
        let repo = CustomMetricsRepo(databaseManager: db)
        try repo.saveDefinition(definition())
        let settingsRepo = UserSettingsRepo(databaseManager: db)
        var settings = try XCTUnwrap(settingsRepo.loadSettings())
        XCTAssertTrue(settings.trackCustomMetrics)
        settings.trackCustomMetrics = false
        XCTAssertTrue(settingsRepo.saveSettings(settings))
        XCTAssertFalse(try XCTUnwrap(settingsRepo.loadSettings()).trackCustomMetrics)
        var existing = try XCTUnwrap(repo.definitions().first)
        existing.name = "Renamed"
        try repo.saveDefinition(existing)
        XCTAssertFalse(try XCTUnwrap(settingsRepo.loadSettings()).trackCustomMetrics)
    }

    func testZeroNoAndMissingRemainDifferentAndClearingRemovesTheObservation() throws {
        let db = try TestDatabaseManager()
        let repo = CustomMetricsRepo(databaseManager: db)
        let number = definition(); let binary = definition(.yesNo, name: "Used support")
        try repo.saveDefinition(number); try repo.saveDefinition(binary)
        XCTAssertTrue(try repo.values(on: date(10)).isEmpty)
        try repo.persist(values: [value(number), value(binary)], clearedIDs: [], on: date(10), log: nil)
        let stored = try repo.values(on: date(10))
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(stored.first { $0.metricID == binary.id }?.booleanValue, false)
        XCTAssertEqual(stored.first { $0.metricID == number.id }?.numberValue, 0)
        XCTAssertTrue(try repo.values(on: date(11)).isEmpty)
        try repo.persist(values: [], clearedIDs: [number.id], on: date(10), log: nil)
        XCTAssertEqual(try repo.values(on: date(10)).count, 1)
        XCTAssertTrue(try LogsRepo(databaseManager: db).loadLogs().isEmpty)
    }

    func testUpdatingOneMetricDoesNotOverwriteOtherValuesOrDuplicateDay() throws {
        let db = try TestDatabaseManager(); let repo = CustomMetricsRepo(databaseManager: db)
        let first = definition(); let second = definition(.count, name: "Repetitions")
        try repo.saveDefinition(first); try repo.saveDefinition(second)
        try repo.persist(values: [value(first, number: 20), value(second, number: 3)], clearedIDs: [], on: date(10), log: nil)
        let created = try XCTUnwrap(repo.values(on: date(10)).first { $0.metricID == first.id }).createdAt
        try repo.persist(values: [value(first, number: 25.5)], clearedIDs: [], on: date(10), log: nil)
        let entries = try repo.values(on: date(10))
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first { $0.metricID == first.id }?.numberValue, 25.5)
        XCTAssertEqual(entries.first { $0.metricID == first.id }?.createdAt, created)
        XCTAssertEqual(entries.first { $0.metricID == second.id }?.numberValue, 3)
    }

    func testRenameArchiveAndRestorePreserveIdentityAndLockMeasurement() throws {
        let db = try TestDatabaseManager(); let repo = CustomMetricsRepo(databaseManager: db)
        var metric = definition()
        try repo.saveDefinition(metric)
        try repo.persist(values: [value(metric, number: 1.5)], clearedIDs: [], on: date(10), log: nil)
        let identity = metric.metricID
        metric.name = "Daily sodium"; metric.archivedAt = Date(); metric.isEnabled = false
        try repo.saveDefinition(metric)
        XCTAssertEqual(try repo.definitions().first?.metricID, identity)
        XCTAssertTrue(try repo.hasHistory(metric.id))
        var incompatible = metric; incompatible.unit = "g"
        XCTAssertThrowsError(try repo.saveDefinition(incompatible))
        metric.archivedAt = nil; metric.isEnabled = true
        try repo.saveDefinition(metric)
        XCTAssertEqual(try repo.allValues().first?.numberValue, 1.5)
    }

    func testMeasurementStaysLockedAfterAllValuesAreCleared() throws {
        let db = try TestDatabaseManager(); let repo = CustomMetricsRepo(databaseManager: db)
        var metric = definition(); try repo.saveDefinition(metric)
        try repo.persist(values: [value(metric, number: 1)], clearedIDs: [], on: date(10), log: nil)
        try repo.persist(values: [], clearedIDs: [metric.id], on: date(10), log: nil)
        XCTAssertTrue(try repo.hasHistory(metric.id))
        metric.unit = "g"
        XCTAssertThrowsError(try repo.saveDefinition(metric))
        metric.id = UUID().uuidString.lowercased()
        XCTAssertNoThrow(try repo.saveDefinition(metric))
    }

    func testTypedValidationRejectsFractionalCountsInvalidScalesAndWrongTypes() throws {
        let count = definition(.count); XCTAssertThrowsError(try value(count, number: -1).validate(for: count))
        XCTAssertThrowsError(try value(count, number: 1.5).validate(for: count))
        XCTAssertThrowsError(try value(count, number: 0.0001).validate(for: count))
        XCTAssertThrowsError(try value(count, number: 0.0000000001).validate(for: count))
        let rating = definition(.rating); XCTAssertThrowsError(try value(rating, number: 11).validate(for: rating))
        let numeric = definition(); XCTAssertThrowsError(try value(numeric, number: .nan).validate(for: numeric))
        // Free numeric units need chart scaling from recorded values, not validation bounds.
        XCTAssertEqual(numeric.analyticsDefinition.domain, .unrestricted)
        XCTAssertThrowsError(try value(numeric, number: 1.23).validate(for: numeric))
        XCTAssertThrowsError(try value(numeric, number: 1.50001).validate(for: numeric))
        var wrong = value(numeric); wrong.booleanValue = false
        XCTAssertThrowsError(try wrong.validate(for: numeric))
        for kind in CustomMetricKind.allCases {
            let metric = definition(kind)
            XCTAssertNoThrow(try value(metric).validate(for: metric))
            XCTAssertTrue(metric.analyticsDefinition.isValid)
        }
    }

    func testNumberInputRequiresWholeValidInputAndSupportsLocalDecimals() {
        XCTAssertNil(CustomMetricInput.number("12mg"))
        XCTAssertNil(CustomMetricInput.number("nan"))
        XCTAssertNil(CustomMetricInput.number("-"))
        XCTAssertEqual(CustomMetricInput.number("-12,5", locale: Locale(identifier: "de_DE")), -12.5)
        XCTAssertEqual(CustomMetricInput.number("12.5", locale: Locale(identifier: "en_US")), 12.5)
    }

    func testMixedCheckInTransactionRollsBackWhenCustomWriteFails() throws {
        let db = try TestDatabaseManager(); let repo = CustomMetricsRepo(databaseManager: db)
        let metric = definition(); try repo.saveDefinition(metric)
        let logs = LogsRepo(databaseManager: db)
        try logs.persistLog(DailyLog(date: date(10), mood: 4))
        try db.write { try $0.execute(sql: "CREATE TRIGGER rejectCustom BEFORE INSERT ON customDailyValue BEGIN SELECT RAISE(ABORT, 'Injected failure'); END") }
        XCTAssertThrowsError(try repo.persist(values: [value(metric, number: 8)], clearedIDs: [], on: date(10), log: DailyLog(date: date(10), mood: 9)))
        XCTAssertEqual(try logs.loadLog(for: date(10))?.mood, 4)
        XCTAssertTrue(try repo.allValues().isEmpty)
    }

    func testCustomOnlyDaysAppearInHistoryAndAnalyticsWithStableIDs() throws {
        let db = try TestDatabaseManager(); let repo = CustomMetricsRepo(databaseManager: db)
        let numeric = definition(); let binary = definition(.yesNo, name: "Support")
        try repo.saveDefinition(numeric); try repo.saveDefinition(binary)
        try repo.persist(values: [value(numeric, number: 2.5), value(binary)], clearedIDs: [], on: date(10), log: nil)
        let day = Calendar.current.startOfDay(for: date(10))
        let summary = try XCTUnwrap(HistoryDaySummaryRepo(databaseManager: db).loadDaySummaries()[day])
        XCTAssertTrue(summary.hasAnyData); XCTAssertNil(summary.log); XCTAssertEqual(summary.customMetrics.count, 2)
        let calendar = Calendar.current
        let repository = DefaultAnalyticsRepository(sourceLoader: GRDBAnalyticsSourceLoader(databaseManager: db, calendar: calendar), calendar: calendar, timeZone: calendar.timeZone)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: day))
        let dataset = try repository.load(AnalyticsRequest(interval: DateInterval(start: day, end: end)))
        XCTAssertEqual(dataset.observations(for: numeric.metricID).first?.state, .observed(.number(2.5)))
        XCTAssertEqual(dataset.observations(for: binary.metricID).first?.state, .observed(.boolean(false)))
        XCTAssertEqual(dataset.coverage[numeric.metricID]?.observedCount, 1)
        XCTAssertEqual(dataset.coverage[numeric.metricID]?.possibleDayCount, 2)
        XCTAssertEqual(CustomMetricProvider(definition: numeric).catalogMetricDefinition?.id, numeric.metricID)
    }

    @MainActor
    func testTodayDoesNotSaveOnLoadAndFlushesCustomOnlyDraftBeforeDateChange() throws {
        let db = try TestDatabaseManager(); let repo = CustomMetricsRepo(databaseManager: db)
        let metric = definition(); try repo.saveDefinition(metric)
        let vm = makeToday(database: db, custom: repo)
        vm.selectedDate = date(10); vm.load()
        XCTAssertEqual(vm.saveState, .saved); XCTAssertTrue(try repo.allValues().isEmpty)
        vm.setCustomValue(value(metric, number: 42), for: metric.id)
        XCTAssertEqual(vm.saveState, .saving)
        vm.selectedDate = date(11); vm.loadLogData(for: date(11))
        XCTAssertEqual(try repo.values(on: date(10)).first?.numberValue, 42)
        XCTAssertTrue(vm.customValues.isEmpty)
        XCTAssertTrue(try LogsRepo(databaseManager: db).loadLogs().isEmpty)
    }

    @MainActor
    func testReturningToTodayRefreshesDefinitionsWithoutOverwritingPendingDrafts() throws {
        let db = try TestDatabaseManager(); let repo = CustomMetricsRepo(databaseManager: db)
        let metric = definition(); try repo.saveDefinition(metric)
        let vm = makeToday(database: db, custom: repo)
        vm.selectedDate = date(10); vm.load()
        vm.setCustomValue(value(metric, number: 7), for: metric.id)
        let added = definition(.count, name: "Steps"); try repo.saveDefinition(added)
        try repo.persist(values: [value(metric, number: 3)], clearedIDs: [], on: date(10), log: nil)
        vm.loadLogData(for: date(10))
        XCTAssertTrue(vm.customDefinitions.contains { $0.id == added.id })
        XCTAssertEqual(vm.customValues[metric.id]?.numberValue, 7)
        XCTAssertTrue(vm.flushPendingChanges())
        try repo.persist(values: [value(metric, number: 4)], clearedIDs: [], on: date(10), log: nil)
        vm.loadLogData(for: date(10))
        XCTAssertEqual(vm.customValues[metric.id]?.numberValue, 4)
        XCTAssertFalse(vm.hasPendingChanges)
    }

    @MainActor
    func testFailedCustomSaveKeepsDraftAndBlocksDateChangeUntilRetry() throws {
        let db = try TestDatabaseManager(); let repo = CustomMetricsRepo(databaseManager: db)
        let metric = definition(); try repo.saveDefinition(metric)
        let vm = makeToday(database: db, custom: repo)
        vm.selectedDate = date(10); vm.load()
        try db.write { try $0.execute(sql: "CREATE TRIGGER rejectCustom BEFORE INSERT ON customDailyValue BEGIN SELECT RAISE(ABORT, 'Injected failure'); END") }
        vm.setCustomValue(value(metric, number: 5), for: metric.id)
        vm.selectedDate = date(11); vm.loadLogData(for: date(11))
        XCTAssertEqual(vm.saveState, .failed)
        XCTAssertEqual(LocalDayKey.make(for: vm.selectedDate), LocalDayKey.make(for: date(10)))
        XCTAssertEqual(vm.customValues[metric.id]?.numberValue, 5)
        try db.write { try $0.execute(sql: "DROP TRIGGER rejectCustom") }
        vm.retrySave()
        XCTAssertEqual(vm.saveState, .saved)
        XCTAssertEqual(try repo.allValues().first?.numberValue, 5)
    }

    func testCSVHasTypesAndUnitsAndCannotBeImportedAsSymptoms() throws {
        let metric = definition(.duration, name: "Screen, time")
        let csv = CustomMetricsCSV.content(definitions: [metric], values: [value(metric, number: 150)])
        XCTAssertTrue(csv.contains("\"Screen, time\",duration,minutes,150"))
        XCTAssertThrowsError(try ImportValidator.validateHeaders(CustomMetricsCSV.headers)) { error in
            guard case ImportError.customMetricsCSV = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }

    @MainActor
    func testFullBackupRestoresDefinitionsValuesSettingsAndLayout() throws {
        let db = try TestDatabaseManager(); let repo = CustomMetricsRepo(databaseManager: db)
        let metric = definition(); try repo.saveDefinition(metric)
        try repo.persist(values: [value(metric, number: 12.5)], clearedIDs: [], on: date(10), log: nil)
        let suite = "CustomMetricsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let layout = Data("layout fixture".utf8); defaults.set(layout, forKey: TodayLayoutPreferences.storageKey)
        let manager = CloveArchiveManager(databaseManager: db, userDefaults: defaults, notificationProvider: { [] }, notificationRestorer: { _ in })
        let url = try manager.createArchiveFile(); defer { try? FileManager.default.removeItem(at: url) }
        try db.write { try $0.execute(sql: "DELETE FROM customDailyValue"); try $0.execute(sql: "DELETE FROM customMetricDefinition") }
        defaults.removeObject(forKey: TodayLayoutPreferences.storageKey)
        _ = try manager.restoreArchive(from: url)
        XCTAssertEqual(try repo.definitions().first?.id, metric.id)
        XCTAssertEqual(try repo.allValues().first?.numberValue, 12.5)
        XCTAssertTrue(try XCTUnwrap(UserSettingsRepo(databaseManager: db).loadSettings()).trackCustomMetrics)
        XCTAssertEqual(defaults.data(forKey: TodayLayoutPreferences.storageKey), layout)
    }

    @MainActor
    func testVersionOneBackupWithoutCustomFieldsStillRestoresWithValidChecksum() throws {
        let db = try TestDatabaseManager()
        let suite = "CustomMetricsLegacy-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let manager = CloveArchiveManager(databaseManager: db, userDefaults: defaults, notificationProvider: { [] }, notificationRestorer: { _ in })
        let archive = try manager.makeArchive()
        var payload = archive.payload
        payload.customMetricDefinitions = nil; payload.customDailyValues = nil
        let manifest = CloveArchive.Manifest(format: archive.manifest.format, schemaVersion: 1, createdAt: archive.manifest.createdAt, appVersion: archive.manifest.appVersion)
        struct Unsigned: Encodable { let manifest: CloveArchive.Manifest; let payload: CloveArchive.Payload }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(Unsigned(manifest: manifest, payload: payload))).map { String(format: "%02x", $0) }.joined()
        let legacy = CloveArchive(manifest: manifest, payload: payload, checksum: digest)
        XCTAssertNoThrow(try manager.restoreArchive(data: encoder.encode(legacy)))
    }

    @MainActor
    private func makeToday(database: TestDatabaseManager, custom: CustomMetricsRepo) -> TodayViewModel {
        TodayViewModel(logsRepository: LogsRepo(databaseManager: database), symptomsRepository: MockSymptomsRepository(),
            settingsRepository: UserSettingsRepo(databaseManager: database), medicationRepository: MockMedicationRepository(),
            bowelMovementRepository: MockBowelMovementRepository(), cycleRepository: MockCycleRepository(), toastManager: MockToastManager(),
            customMetricsRepository: custom)
    }
}
