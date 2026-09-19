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

    func testSymptomIdentitySurvivesRenameRemovalAndReEnableAcrossAnalyticsSurfaces() throws {
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

        XCTAssertTrue(symptoms.updateSymptom(id: originalID, name: "Exhaustion", isBinary: false))
        let renamed = try XCTUnwrap(symptoms.getAllSymptoms().first { $0.id == originalID })
        let activeProvider = try XCTUnwrap(SymptomMetricCatalog.providers(
            storedSymptoms: symptoms.getAllSymptoms(),
            logs: [DailyLog(
                date: date,
                symptomRatings: [SymptomRating(symptomId: originalID, symptomName: "Fatigue", rating: 6)]
            )]
        ).first { $0.symptomID == originalID })
        XCTAssertEqual(activeProvider.id, "symptom:\(originalID)")
        XCTAssertEqual(activeProvider.displayName, "Exhaustion")
        XCTAssertEqual(MetricAvailabilityResolver.state(for: activeProvider, observedCount: 0), .noDataInRange)

        XCTAssertTrue(symptoms.deleteSymptom(id: originalID))
        XCTAssertFalse(symptoms.getTrackedSymptoms().contains { $0.id == originalID })
        let deletedProvider = try XCTUnwrap(SymptomMetricCatalog.providers(
            storedSymptoms: symptoms.getAllSymptoms(),
            logs: []
        ).first { $0.symptomID == originalID })
        XCTAssertEqual(MetricAvailabilityResolver.state(for: deletedProvider, observedCount: 1), .deleted)

        XCTAssertTrue(symptoms.saveSymptom(TrackedSymptom(name: "Exhaustion")))
        let recreatedID = try XCTUnwrap(symptoms.getTrackedSymptoms().last?.id)
        XCTAssertEqual(originalID, recreatedID)

        let repository = DefaultAnalyticsRepository(
            sourceLoader: GRDBAnalyticsSourceLoader(databaseManager: database),
            timeZone: AnalyticsTestDates.utc
        )
        let dataset = try repository.load(AnalyticsRequest(interval: DateInterval(start: date, duration: 86_400)))
        let historicalID = DynamicMetricIdentityStore.canonicalID(family: .symptom, sourceID: originalID)
        XCTAssertTrue(dataset.definitions.contains { $0.id == historicalID && $0.displayName == "Exhaustion" })
        XCTAssertEqual(dataset.observations(for: historicalID).count, 1)
        XCTAssertEqual(dataset.metricAliases["symptom_fatigue"], [historicalID])
        XCTAssertEqual(dataset.metricAliases["symptom_exhaustion"], [historicalID])

        let currentProvider = try XCTUnwrap(SymptomMetricCatalog.providers(
            storedSymptoms: [renamed],
            logs: []
        ).first)
        let provider = MetricProviderResolver.resolve(
            id: "symptom_fatigue",
            metrics: [currentProvider.id: currentProvider],
            aliases: ["symptom_fatigue": historicalID.rawValue]
        )
        XCTAssertEqual(provider?.id, historicalID.rawValue)
    }
}
