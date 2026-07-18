import GRDB
import XCTest
@testable import Clove

final class DynamicMetricIdentityTests: XCTestCase {
    func testMigrationPreservesHistorySeparatesSlugCollisionsAndIsIdempotent() throws {
        // Stable identity is followed by later, unrelated feature migrations.
        let baseMigrations = Array(Migrations.all.prefix { $0.identifier != StableDynamicMetricIdentityMigration().identifier })
        let database = try TestDatabaseManager(migrations: baseMigrations)
        let date = AnalyticsTestDates.date(2024, 4, 1)
        try database.write { db in
            try db.execute(
                sql: "INSERT INTO foodEntry (name, category, date, isFavorite) VALUES (?, ?, ?, 0), (?, ?, ?, 0)",
                arguments: ["A B", "snack", date, "A_B", "snack", date]
            )
            try db.execute(
                sql: "INSERT INTO activityEntry (name, category, date, isFavorite) VALUES (?, ?, ?, 0)",
                arguments: ["Morning Walk", "exercise", date]
            )
            try db.execute(sql: "INSERT INTO trackedSymptom (name, isBinary) VALUES ('Fatigue', 0)")
            try db.execute(sql: "INSERT INTO trackedMedication (name, dosage, instructions, isAsNeeded) VALUES ('Vitamin D', '', '', 0)")
        }

        try database.migrate(Migrations.all)
        try database.migrate(Migrations.all)

        let foods = try database.read { db in try FoodEntry.order(Column("id").asc).fetchAll(db) }
        XCTAssertEqual(Set(foods.compactMap(\.analyticsIdentityID)).count, 2)
        let collidingAliases = try database.read { db in
            try MetricIdentityAlias.filter(Column("aliasID") == "meal_a_b").fetchAll(db)
        }
        XCTAssertEqual(Set(collidingAliases.map(\.canonicalID)).count, 2)
    }

    func testRenameKeepsCanonicalIdentityAndBothAliasesResolveAfterRelaunch() throws {
        let database = try TestDatabaseManager()
        let revision = TestRevisionSource()
        let foods = FoodEntryRepo(databaseManager: database, analyticsRevisionSource: revision)
        let date = AnalyticsTestDates.date(2024, 5, 1)
        XCTAssertNotNil(foods.save(FoodEntry(name: "Oatmeal", category: .breakfast, date: date)))
        var entry = try XCTUnwrap(foods.getAllEntries().first)
        let identity = try XCTUnwrap(entry.analyticsIdentityID)
        entry.name = "Overnight Oats"
        XCTAssertTrue(foods.update(entry))
        XCTAssertEqual(foods.getAllEntries().first?.analyticsIdentityID, identity)

        let repositoryAfterRelaunch = DefaultAnalyticsRepository(
            sourceLoader: GRDBAnalyticsSourceLoader(databaseManager: database),
            timeZone: AnalyticsTestDates.utc
        )
        let dataset = try repositoryAfterRelaunch.load(AnalyticsRequest(
            interval: DateInterval(start: date, duration: 86_400)
        ))
        let canonical = DynamicMetricIdentityStore.canonicalID(family: .meal, sourceID: identity)
        XCTAssertTrue(dataset.definitions.contains { $0.id == canonical && $0.displayName == "Overnight Oats" })
        XCTAssertEqual(dataset.metricAliases["meal_oatmeal"], [canonical])
        XCTAssertEqual(dataset.metricAliases["meal_overnight_oats"], [canonical])
        XCTAssertFalse(dataset.observations(for: canonical).isEmpty)
    }

    func testDeletedHistoricalSymptomRemainsAnalyzableAndRecreationGetsNewID() throws {
        let database = try TestDatabaseManager()
        let revision = TestRevisionSource()
        let symptoms = SymptomsRepo(databaseManager: database, analyticsRevisionSource: revision)
        XCTAssertTrue(symptoms.saveSymptom(TrackedSymptom(name: "Fatigue")))
        let originalID = try XCTUnwrap(symptoms.getTrackedSymptoms().last?.id)
        let date = AnalyticsTestDates.date(2024, 6, 1)
        try database.write { db in
            try DailyLog(
                date: date,
                symptomRatings: [SymptomRating(symptomId: originalID, symptomName: "Fatigue", rating: 6)]
            ).insert(db)
        }
        XCTAssertTrue(symptoms.deleteSymptom(id: originalID))
        XCTAssertTrue(symptoms.saveSymptom(TrackedSymptom(name: "Fatigue")))
        let recreatedID = try XCTUnwrap(symptoms.getTrackedSymptoms().last?.id)
        XCTAssertNotEqual(originalID, recreatedID)

        let repository = DefaultAnalyticsRepository(
            sourceLoader: GRDBAnalyticsSourceLoader(databaseManager: database),
            timeZone: AnalyticsTestDates.utc
        )
        let dataset = try repository.load(AnalyticsRequest(interval: DateInterval(start: date, duration: 86_400)))
        let historicalID = DynamicMetricIdentityStore.canonicalID(family: .symptom, sourceID: originalID)
        XCTAssertTrue(dataset.definitions.contains { $0.id == historicalID })
        XCTAssertEqual(dataset.observations(for: historicalID).count, 1)
    }
}
