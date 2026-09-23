import Foundation
import GRDB
import XCTest
@testable import Clove

final class CloveArchiveTests: XCTestCase {
    func testFullBackupRestoresDataMissingFromCSV() throws {
        let database = try TestDatabaseManager()
        let revision = TestRevisionSource()
        let suiteName = "CloveArchiveTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let originalTheme = Theme.shared.accent
        defer { Theme.shared.accent = originalTheme }
        let backedUpColor = "0.1,0.2,0.3,1.0"
        defaults.set(backedUpColor, forKey: Constants.SELECTED_COLOR)
        defaults.set(80, forKey: Constants.HYDRATION_GOAL_OUNCES)
        defaults.set(false, forKey: Constants.HYDRATION_GOAL_ENABLED)
        defaults.set(HydrationUnit.milliliters.rawValue, forKey: Constants.HYDRATION_UNIT)
        defaults.set([200, 400, 600], forKey: Constants.HYDRATION_QUICK_AMOUNTS_MILLILITERS)

        let reminder = ScheduledNotification(
            id: "morning-check-in",
            title: "Check in",
            body: "How are you feeling?",
            hour: 9,
            minute: 15,
            isEnabled: true,
            createdAt: AnalyticsTestDates.date(2026, 9, 1)
        )
        var restoredNotifications: [ScheduledNotification] = []
        let manager = CloveArchiveManager(
            databaseManager: database,
            analyticsRevisionSource: revision,
            userDefaults: defaults,
            notificationProvider: { [reminder] },
            notificationRestorer: { restoredNotifications = $0 }
        )

        try seedFullFidelityData(in: database)
        let archiveURL = try manager.createArchiveFile()
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        try database.write { db in
            try db.execute(sql: "DELETE FROM dailyLog")
            try db.execute(sql: "DELETE FROM trackedSymptom")
            try db.execute(sql: "DELETE FROM trackedMedication")
            try db.execute(sql: "DELETE FROM medicationHistoryEntry")
            try db.execute(sql: "DELETE FROM foodEntry")
            try db.execute(sql: "DELETE FROM activityEntry")
            try db.execute(sql: "DELETE FROM pacingPlanItem")
            try db.execute(sql: "DELETE FROM cycle")
            try db.execute(sql: "DELETE FROM savedAnalysis")
        }
        defaults.set("0.8,0.2,0.4,1.0", forKey: Constants.SELECTED_COLOR)
        Theme.shared.accent = .pink
        defaults.set(12, forKey: Constants.HYDRATION_GOAL_OUNCES)
        defaults.set(true, forKey: Constants.HYDRATION_GOAL_ENABLED)
        defaults.set(HydrationUnit.fluidOunces.rawValue, forKey: Constants.HYDRATION_UNIT)

        let result = try manager.restoreArchive(from: archiveURL)

        let restored = try database.read { db in
            (
                try DailyLog.fetchOne(db),
                try TrackedSymptom.fetchOne(db),
                try TrackedMedication.fetchOne(db),
                try MedicationHistoryEntry.fetchOne(db),
                try FoodEntry.fetchOne(db),
                try ActivityEntry.fetchOne(db),
                try PacingPlanItem.fetchOne(db),
                try Cycle.fetchOne(db),
                try SavedAnalysis.fetchOne(db)
            )
        }
        XCTAssertEqual(result.dailyLogCount, 1)
        XCTAssertEqual(restored.0?.waterIntake, 72)
        XCTAssertEqual(restored.0?.medicationAdherence.first?.notes, "with breakfast")
        XCTAssertEqual(restored.1?.isBinary, true)
        XCTAssertEqual(restored.2?.dosage, "10 mg")
        XCTAssertEqual(restored.3?.changeType, "dosage_changed")
        XCTAssertEqual(restored.4?.notes, "extra ginger")
        XCTAssertEqual(restored.4?.isFavorite, true)
        XCTAssertEqual(restored.5?.duration, 35)
        XCTAssertEqual(restored.5?.intensity, .medium)
        XCTAssertEqual(restored.6?.title, "Call a friend")
        XCTAssertEqual(restored.6?.state, .deferred)
        XCTAssertEqual(restored.7?.flow, .heavy)
        XCTAssertEqual(restored.8?.title, "Sleep vs pain")
        XCTAssertEqual(defaults.string(forKey: Constants.SELECTED_COLOR), backedUpColor)
        let restoredColorComponents = Theme.shared.accent.toString()
            .split(separator: ",")
            .compactMap { Double($0) }
        XCTAssertEqual(restoredColorComponents.count, 4)
        XCTAssertEqual(restoredColorComponents[0], 0.1, accuracy: 0.0001)
        XCTAssertEqual(restoredColorComponents[1], 0.2, accuracy: 0.0001)
        XCTAssertEqual(restoredColorComponents[2], 0.3, accuracy: 0.0001)
        XCTAssertEqual(restoredColorComponents[3], 1.0, accuracy: 0.0001)
        XCTAssertEqual(defaults.integer(forKey: Constants.HYDRATION_GOAL_OUNCES), 80)
        XCTAssertFalse(defaults.bool(forKey: Constants.HYDRATION_GOAL_ENABLED))
        XCTAssertEqual(defaults.string(forKey: Constants.HYDRATION_UNIT), HydrationUnit.milliliters.rawValue)
        XCTAssertEqual(defaults.array(forKey: Constants.HYDRATION_QUICK_AMOUNTS_MILLILITERS) as? [Int], [200, 400, 600])
        let recoveryURL = try XCTUnwrap(manager.latestRecoveryCheckpointURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recoveryURL.path))
        XCTAssertNoThrow(try CloveArchiveManager.validateArchiveFile(at: recoveryURL))
        XCTAssertEqual(restoredNotifications.map(\.id), ["morning-check-in"])
        XCTAssertEqual(revision.reasons.map(\.rawValue), [AnalyticsRevisionReason.dataImport.rawValue])
    }

    func testInvalidChecksumDoesNotReplaceExistingData() throws {
        let database = try TestDatabaseManager()
        let suiteName = "CloveArchiveTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = CloveArchiveManager(
            databaseManager: database,
            analyticsRevisionSource: TestRevisionSource(),
            userDefaults: defaults,
            notificationProvider: { [] },
            notificationRestorer: { _ in }
        )

        try database.write { db in
            try DailyLog(date: AnalyticsTestDates.date(2026, 9, 1), mood: 8).insert(db)
        }
        let validURL = try manager.createArchiveFile()
        defer { try? FileManager.default.removeItem(at: validURL) }
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: validURL)) as? [String: Any]
        )
        object["checksum"] = String(repeating: "0", count: 64)
        let damagedData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try manager.restoreArchive(data: damagedData)) { error in
            guard case CloveArchiveError.checksumMismatch = error else {
                return XCTFail("Expected checksum mismatch, got \(error)")
            }
        }
        let log = try database.read { try DailyLog.fetchOne($0) }
        XCTAssertEqual(log?.mood, 8)
    }

    private func seedFullFidelityData(in database: DatabaseManaging) throws {
        try database.write { db in
            try TrackedSymptom(id: 41, name: "Fainted", isBinary: true).insert(db)
            var medication = TrackedMedication(name: "Example med", dosage: "10 mg", instructions: "Daily")
            medication.id = 22
            try medication.insert(db)
            var history = MedicationHistoryEntry(
                medicationId: 22,
                medicationName: "Example med",
                changeType: "dosage_changed",
                oldValue: "5 mg",
                newValue: "10 mg"
            )
            history.id = 23
            try history.insert(db)
            try DailyLog(
                id: 31,
                date: AnalyticsTestDates.date(2026, 9, 17),
                mood: 6,
                waterIntake: 72,
                medicationAdherence: [
                    MedicationAdherence(
                        medicationId: 22,
                        medicationName: "Example med",
                        wasTaken: true,
                        notes: "with breakfast"
                    )
                ],
                symptomRatings: [SymptomRating(symptomId: 41, symptomName: "Fainted", rating: 1)]
            ).insert(db)
            try FoodEntry(
                id: 51,
                name: "Soup",
                category: .lunch,
                date: AnalyticsTestDates.date(2026, 9, 17, hour: 12),
                notes: "extra ginger",
                isFavorite: true
            ).insert(db)
            try ActivityEntry(
                id: 61,
                name: "Walk",
                category: .exercise,
                date: AnalyticsTestDates.date(2026, 9, 17, hour: 14),
                duration: 35,
                intensity: .medium
            ).insert(db)
            try PacingPlanItem(
                id: 65,
                title: "Call a friend",
                date: AnalyticsTestDates.date(2026, 9, 17),
                state: .deferred,
                sortOrder: 0,
                createdAt: AnalyticsTestDates.date(2026, 9, 17, hour: 8),
                updatedAt: AnalyticsTestDates.date(2026, 9, 17, hour: 9)
            ).insert(db)
            try Cycle(
                id: 71,
                date: AnalyticsTestDates.date(2026, 9, 17),
                flow: .heavy,
                isStartOfCycle: true,
                hasCramps: true
            ).insert(db)
            try SavedAnalysis(
                id: 81,
                title: "Sleep vs pain",
                factorMetricID: "sleep",
                outcomeMetricID: "pain",
                rangePolicy: "month"
            ).insert(db)
        }
    }
}
