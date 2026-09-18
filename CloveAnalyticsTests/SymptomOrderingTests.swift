import XCTest
import GRDB
@testable import Clove

final class SymptomOrderingTests: XCTestCase {
    func testMigrationAssignsExistingSymptomsDeterministicallyByID() throws {
        let database = try TestDatabaseManager(migrations: Array(Migrations.all.dropLast()))
        try database.write { db in
            try db.execute(sql: "INSERT INTO trackedSymptom (id, name, isBinary) VALUES (9, 'Third', 0)")
            try db.execute(sql: "INSERT INTO trackedSymptom (id, name, isBinary) VALUES (2, 'First', 0)")
            try db.execute(sql: "INSERT INTO trackedSymptom (id, name, isBinary) VALUES (5, 'Second', 1)")
        }

        try database.migrate([SymptomDisplayOrderMigration()])

        let rows = try database.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT id, displayOrder FROM trackedSymptom ORDER BY displayOrder ASC"
            )
        }
        XCTAssertEqual(rows.map { $0["id"] as Int64 }, [2, 5, 9])
        XCTAssertEqual(rows.map { $0["displayOrder"] as Int }, [0, 1, 2])
    }

    func testReorderPersistsAcrossRepositoryInstancesAndNewSymptomsAppend() throws {
        let database = try TestDatabaseManager()
        let revision = TestRevisionSource()
        let repository = SymptomsRepo(databaseManager: database, analyticsRevisionSource: revision)
        XCTAssertTrue(repository.saveTrackedSymptoms([
            TrackedSymptom(name: "Headache"),
            TrackedSymptom(name: "Fatigue"),
            TrackedSymptom(name: "Nausea", isBinary: true)
        ]))

        let initial = repository.getTrackedSymptoms()
        XCTAssertEqual(initial.map(\.name), ["Headache", "Fatigue", "Nausea"])
        XCTAssertTrue(repository.reorderSymptoms([initial[2], initial[0], initial[1]]))

        let relaunchedRepository = SymptomsRepo(
            databaseManager: database,
            analyticsRevisionSource: TestRevisionSource()
        )
        XCTAssertEqual(relaunchedRepository.getTrackedSymptoms().map(\.name), ["Nausea", "Headache", "Fatigue"])

        XCTAssertTrue(relaunchedRepository.saveSymptom(TrackedSymptom(name: "Bloating")))
        XCTAssertEqual(
            relaunchedRepository.getTrackedSymptoms().map(\.name),
            ["Nausea", "Headache", "Fatigue", "Bloating"]
        )
    }

    func testInvalidReorderRollsBackWithoutChangingOrder() throws {
        let database = try TestDatabaseManager()
        let repository = SymptomsRepo(
            databaseManager: database,
            analyticsRevisionSource: TestRevisionSource()
        )
        XCTAssertTrue(repository.saveTrackedSymptoms([
            TrackedSymptom(name: "One"),
            TrackedSymptom(name: "Two"),
            TrackedSymptom(name: "Three")
        ]))
        let initial = repository.getTrackedSymptoms()

        XCTAssertFalse(repository.reorderSymptoms(Array(initial.dropLast())))
        XCTAssertEqual(repository.getTrackedSymptoms().map(\.name), ["One", "Two", "Three"])
    }

    func testAnalyticsDefinitionsUseTrackedSymptomOrder() throws {
        let database = try TestDatabaseManager()
        let repository = SymptomsRepo(
            databaseManager: database,
            analyticsRevisionSource: TestRevisionSource()
        )
        XCTAssertTrue(repository.saveTrackedSymptoms([
            TrackedSymptom(name: "Headache"),
            TrackedSymptom(name: "Fatigue"),
            TrackedSymptom(name: "Nausea")
        ]))
        let initial = repository.getTrackedSymptoms()
        XCTAssertTrue(repository.reorderSymptoms([initial[2], initial[0], initial[1]]))

        let start = AnalyticsTestDates.date(2026, 9, 1)
        let analytics = DefaultAnalyticsRepository(
            sourceLoader: GRDBAnalyticsSourceLoader(databaseManager: database),
            timeZone: AnalyticsTestDates.utc
        )
        let dataset = try analytics.load(AnalyticsRequest(
            interval: DateInterval(start: start, duration: 86_400)
        ))

        XCTAssertEqual(
            dataset.definitions.filter { $0.source == .symptomRatings }.map(\.displayName),
            ["Nausea", "Headache", "Fatigue"]
        )
    }

    func testLegacyBackupSymptomDecodesWithoutDisplayOrder() throws {
        let data = Data(#"{"id":41,"name":"Fainted","isBinary":true}"#.utf8)
        let symptom = try JSONDecoder().decode(TrackedSymptom.self, from: data)

        XCTAssertEqual(symptom.displayOrder, 0)
        let reencoded = try JSONEncoder().encode(symptom)
        XCTAssertFalse(String(decoding: reencoded, as: UTF8.self).contains("displayOrder"))
    }
}
