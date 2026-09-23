import Foundation
import GRDB
import XCTest
@testable import Clove

final class DataImportAtomicityTests: XCTestCase {
    func testSuccessfulImportReplacesRecordsInOneCommit() async throws {
        let database = try TestDatabaseManager()
        let revision = TestRevisionSource()
        try seedOriginalLog(in: database)
        let csvURL = try makeRepresentativeCSV()
        defer { try? FileManager.default.removeItem(at: csvURL) }

        let manager = DataImportManager(
            databaseManager: database,
            analyticsRevisionSource: revision
        )
        let result = try await manager.performImport(from: csvURL)

        let snapshot = try snapshot(in: database)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.importedLogsCount, 1)
        XCTAssertEqual(snapshot.logs.count, 1)
        XCTAssertEqual(snapshot.logs.first?.mood, 3)
        XCTAssertEqual(snapshot.logs.first?.waterIntake, 64)
        XCTAssertEqual(snapshot.logs.first?.symptomRatings.first?.rating, 7)
        XCTAssertEqual(snapshot.foodCount, 1)
        XCTAssertEqual(snapshot.activityCount, 1)
        XCTAssertEqual(snapshot.bowelCount, 1)
        XCTAssertEqual(snapshot.symptomCount, 1)
        XCTAssertEqual(revision.reasons.map(\.rawValue), [AnalyticsRevisionReason.dataImport.rawValue])
    }

    func testFailureAfterAllWritesRollsBackOriginalDatabase() async throws {
        let database = try FailingImportDatabaseManager()
        let revision = TestRevisionSource()
        try seedOriginalLog(in: database)
        let csvURL = try makeRepresentativeCSV()
        defer { try? FileManager.default.removeItem(at: csvURL) }

        database.failNextWriteReturning = true
        let manager = DataImportManager(
            databaseManager: database,
            analyticsRevisionSource: revision
        )

        do {
            _ = try await manager.performImport(from: csvURL)
            XCTFail("Expected the injected transaction failure")
        } catch FailingImportDatabaseManager.Failure.injected {
            // Expected. Throwing before DatabaseQueue.write returns rolls back
            // every deletion and insertion in the transaction.
        }

        let snapshot = try snapshot(in: database)
        XCTAssertEqual(snapshot.logs.count, 1)
        XCTAssertEqual(snapshot.logs.first?.mood, 9)
        XCTAssertEqual(snapshot.logs.first?.waterIntake, 12)
        XCTAssertEqual(snapshot.foodCount, 0)
        XCTAssertEqual(snapshot.activityCount, 0)
        XCTAssertEqual(snapshot.bowelCount, 0)
        XCTAssertEqual(snapshot.symptomCount, 0)
        XCTAssertEqual(revision.currentRevision, 0)
    }

    func testReplacementDoesNotStartWhenRecoveryCheckpointFails() async throws {
        struct CheckpointFailure: Error {}

        let database = try TestDatabaseManager()
        let revision = TestRevisionSource()
        try seedOriginalLog(in: database)
        let csvURL = try makeRepresentativeCSV()
        defer { try? FileManager.default.removeItem(at: csvURL) }

        let manager = DataImportManager(
            databaseManager: database,
            analyticsRevisionSource: revision,
            recoveryCheckpointProvider: { throw CheckpointFailure() }
        )

        do {
            _ = try await manager.performImport(from: csvURL)
            XCTFail("Expected checkpoint creation to stop replacement")
        } catch is CheckpointFailure {
            // Expected.
        }

        let snapshot = try snapshot(in: database)
        XCTAssertEqual(snapshot.logs.count, 1)
        XCTAssertEqual(snapshot.logs.first?.mood, 9)
        XCTAssertEqual(snapshot.logs.first?.waterIntake, 12)
        XCTAssertEqual(revision.currentRevision, 0)
    }

    private func seedOriginalLog(in database: DatabaseManaging) throws {
        try database.write { db in
            try DailyLog(
                date: AnalyticsTestDates.date(2026, 9, 17, hour: 12),
                mood: 9,
                waterIntake: 12
            ).insert(db)
        }
    }

    private func makeRepresentativeCSV() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let date = formatter.string(from: AnalyticsTestDates.date(2026, 9, 18, hour: 12))
        let headers = [
            "Date", "Mood", "Hydration (oz)", "Bowel Movements",
            "Meals", "Activities", "Joint pain"
        ]
        let row = [
            date, "3", "64", "Type 4 (1:30 PM)",
            "Soup (Lunch)", "Walk (Exercise)", "7"
        ]
        let content = [headers, row]
            .map { $0.map(escapeCSVField).joined(separator: ",") }
            .joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("csv")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func escapeCSVField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func snapshot(in database: DatabaseManaging) throws -> (
        logs: [DailyLog],
        foodCount: Int,
        activityCount: Int,
        bowelCount: Int,
        symptomCount: Int
    ) {
        try database.read { db in
            (
                try DailyLog.fetchAll(db),
                try FoodEntry.fetchCount(db),
                try ActivityEntry.fetchCount(db),
                try BowelMovement.fetchCount(db),
                try TrackedSymptom.fetchCount(db)
            )
        }
    }
}

private final class FailingImportDatabaseManager: DatabaseManaging {
    enum Failure: Error {
        case injected
    }

    let queue: DatabaseQueue
    var failNextWriteReturning = false

    init() throws {
        queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        for migration in Migrations.all {
            migrator.registerMigration(migration.identifier) { db in
                try migration.migrate(db)
            }
        }
        try migrator.migrate(queue)
    }

    func setupDatabase() throws {}
    func resetDatabase() throws {}

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        try queue.read(block)
    }

    func write(_ block: (Database) throws -> Void) throws {
        try queue.write(block)
    }

    func writeReturning<T>(_ block: (Database) throws -> T) throws -> T {
        try queue.write { db in
            let result = try block(db)
            if failNextWriteReturning {
                failNextWriteReturning = false
                throw Failure.injected
            }
            return result
        }
    }
}
