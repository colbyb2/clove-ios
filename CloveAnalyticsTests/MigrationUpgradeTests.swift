import Foundation
import GRDB
import XCTest
@testable import Clove

/// Guards the path every existing user takes on app update: an old on-disk
/// schema with real rows, migrated forward by the production migrator.
///
/// Several historical migrations decode rows through *current* model types
/// (for example `DailyLog` and `TrackedSymptom`). Adding a non-optional model
/// field without a decoding fallback silently breaks upgrades from old
/// versions; the full-chain test below catches that.
final class MigrationUpgradeTests: XCTestCase {
    func testMigrationIdentifiersAreUniqueAndNonEmpty() {
        let identifiers = Migrations.all.map(\.identifier)
        XCTAssertFalse(identifiers.contains(""), "Every migration needs an identifier")
        XCTAssertEqual(
            Set(identifiers).count,
            identifiers.count,
            "Duplicate identifiers: \(duplicates(in: identifiers))"
        )
    }

    func testInitialMigrationStaysFirstSoExistingInstallsKeepTheirHistory() {
        // GRDB records applied identifiers. Renaming or reordering shipped
        // migrations makes existing installs re-run or skip schema changes.
        XCTAssertEqual(Migrations.all.first?.identifier, "initial")
        XCTAssertEqual(Migrations.all.dropFirst().first?.identifier, "userSettings_061825")
    }

    func testRunningTheMigratorTwiceIsANoOp() throws {
        let database = try TestDatabaseManager()
        try database.write { db in
            try DailyLog(date: AnalyticsTestDates.date(3), mood: 4).insert(db)
        }
        let before = try schema(of: database)

        XCTAssertNoThrow(try database.migrate(Migrations.all))

        XCTAssertEqual(try schema(of: database), before)
        XCTAssertEqual(try database.read { try DailyLog.fetchCount($0) }, 1)
    }

    func testFreshInstallCreatesEveryTableThatModelsPersistTo() throws {
        let database = try TestDatabaseManager()
        let tables = try database.read { db in
            try String.fetchSet(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        }

        let modelTables = [
            DailyLog.databaseTableName,
            TrackedSymptom.databaseTableName,
            UserSettings.databaseTableName,
            TrackedMedication.databaseTableName,
            MedicationHistoryEntry.databaseTableName,
            BowelMovement.databaseTableName,
            FoodEntry.databaseTableName,
            ActivityEntry.databaseTableName,
            ActivityCategoryDefinition.databaseTableName,
            Cycle.databaseTableName,
            PacingPlanItem.databaseTableName,
            SavedAnalysis.databaseTableName,
            InsightFeedback.databaseTableName,
            SavedHypothesis.databaseTableName,
            DynamicMetricIdentity.databaseTableName,
            MetricIdentityAlias.databaseTableName
        ]
        for table in modelTables {
            XCTAssertTrue(tables.contains(table), "Missing table \(table)")
        }
    }

    func testFreshInstallSeedsOneUsableSettingsRow() throws {
        let database = try TestDatabaseManager()
        let repo = UserSettingsRepo(databaseManager: database)

        let settings = try XCTUnwrap(try repo.loadSettings())
        XCTAssertEqual(settings.id, 1)
        XCTAssertEqual(try database.read { try UserSettings.fetchCount($0) }, 1)
    }

    /// Simulates a user who installed the very first release, logged data,
    /// and is now updating straight to the current build.
    func testUpgradeFromFirstReleasePreservesEveryLegacyRecord() throws {
        let database = try TestDatabaseManager(migrations: Array(Migrations.all.prefix(2)))
        let logDate = AnalyticsTestDates.date(2025, 3, 14, hour: 12, timeZone: .current)

        try database.write { db in
            try db.execute(sql: "INSERT INTO trackedSymptom (id, name) VALUES (7, 'Headache')")
            try db.execute(
                sql: """
                INSERT INTO dailyLog
                    (date, mood, painLevel, energyLevel, meals, activities, medicationsTaken,
                     notes, isFlareDay, symptomRatingsJSON)
                VALUES (?, 6, 3, 5, ?, ?, ?, ?, 1, ?)
                """,
                arguments: [
                    logDate,
                    #"["Oatmeal","Chicken sandwich"]"#,
                    #"["Walking"]"#,
                    #"["Ibuprofen"]"#,
                    "Felt foggy",
                    #"[{"symptomName":"Headache","rating":6}]"#
                ]
            )
            try db.execute(sql: "UPDATE userSettings SET trackPain = 0 WHERE id = 1")
        }

        try database.migrate(Migrations.all)

        let log = try XCTUnwrap(LogsRepo(databaseManager: database).loadLog(for: logDate))
        XCTAssertEqual(log.mood, 6)
        XCTAssertEqual(log.painLevel, 3)
        XCTAssertEqual(log.energyLevel, 5)
        XCTAssertEqual(log.notes, "Felt foggy")
        XCTAssertTrue(log.isFlareDay)
        XCTAssertEqual(log.dayKey, LocalDayKey.make(for: logDate))
        XCTAssertEqual(log.symptomRatings.map(\.symptomId), [7], "Legacy ratings gain symptom IDs")
        XCTAssertEqual(log.symptomRatings.map(\.rating), [6])

        let symptoms = try SymptomsRepo(databaseManager: database).loadTrackedSymptoms()
        XCTAssertEqual(symptoms.map(\.name), ["Headache"])
        XCTAssertEqual(symptoms.first?.isBinary, false)
        XCTAssertEqual(symptoms.first?.isActive, true)

        let foods = try database.read { try FoodEntry.order(Column("name")).fetchAll($0) }
        XCTAssertEqual(foods.map(\.name), ["Chicken sandwich", "Oatmeal"])
        XCTAssertEqual(foods.map(\.category), [.lunch, .breakfast])
        XCTAssertTrue(foods.allSatisfy { $0.analyticsIdentityID != nil }, "Migrated meals need analytics identity")

        let activities = try database.read { try ActivityEntry.fetchAll($0) }
        XCTAssertEqual(activities.map(\.name), ["Walking"])
        XCTAssertNotNil(activities.first?.categoryID)

        let settings = try XCTUnwrap(try UserSettingsRepo(databaseManager: database).loadSettings())
        XCTAssertFalse(settings.trackPain, "User choices survive later settings migrations")
        XCTAssertTrue(settings.trackMood)
    }

    func testEachMigrationPrefixLeavesADecodableDatabase() throws {
        // Stopping at any intermediate version and then upgrading must work:
        // users skip arbitrary numbers of releases.
        for count in 1..<Migrations.all.count {
            let database = try TestDatabaseManager(migrations: Array(Migrations.all.prefix(count)))
            XCTAssertNoThrow(
                try database.migrate(Migrations.all),
                "Upgrade failed after \(Migrations.all[count - 1].identifier)"
            )
            XCTAssertNoThrow(try database.read { try UserSettings.fetchOne($0) })
        }
    }

    // MARK: - Helpers

    private func schema(of database: TestDatabaseManager) throws -> [String] {
        try database.read { db in
            try String.fetchAll(db, sql: """
                SELECT type || ':' || name || ':' || IFNULL(sql, '')
                FROM sqlite_master
                WHERE name NOT LIKE 'sqlite_%'
                ORDER BY type, name
                """)
        }
    }

    private func duplicates(in values: [String]) -> [String] {
        Dictionary(grouping: values, by: { $0 }).filter { $0.value.count > 1 }.map(\.key)
    }
}
