import Foundation
import GRDB
import XCTest
@testable import Clove

final class DailyLogDayIdentityTests: XCTestCase {
    func testMigrationMergesDuplicateDaysAndAddsUniqueConstraint() throws {
        let migrationsBeforeDayKey = Array(Migrations.all.prefix {
            $0.identifier != DailyLogDayKeyMigration().identifier
        })
        let database = try TestDatabaseManager(migrations: migrationsBeforeDayKey)
        let calendar = calendar(in: "UTC")
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 8)))
        let evening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 20)))

        try database.write { db in
            try insertLegacyLog(
                in: db,
                date: morning,
                mood: 7,
                pain: nil,
                notes: "Morning note"
            )
            try insertLegacyLog(
                in: db,
                date: evening,
                mood: nil,
                pain: 4,
                notes: "Evening note"
            )
        }

        try database.migrate([DailyLogDayKeyMigration(calendar: calendar)])

        let logs = try database.read { db in try DailyLog.fetchAll(db) }
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].dayKey, "2026-09-18")
        XCTAssertEqual(logs[0].mood, 7)
        XCTAssertEqual(logs[0].painLevel, 4)
        XCTAssertEqual(logs[0].notes, "Morning note\n\nEvening note")

        XCTAssertThrowsError(try database.write { db in
            try DailyLog(date: evening, dayKey: "2026-09-18").insert(db)
        })
    }

    func testConcurrentSavesUpsertOneRecordPerDay() throws {
        let database = try TestDatabaseManager()
        let calendar = calendar(in: "UTC")
        let repository = LogsRepo(
            databaseManager: database,
            analyticsRevisionSource: LockedRevisionSource(),
            calendar: calendar
        )
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 12)))
        let resultLock = NSLock()
        var results: [Bool] = []

        DispatchQueue.concurrentPerform(iterations: 20) { value in
            let saved = repository.saveLog(DailyLog(date: date, mood: value))
            resultLock.lock()
            results.append(saved)
            resultLock.unlock()
        }

        XCTAssertEqual(results.count, 20)
        XCTAssertTrue(results.allSatisfy { $0 })
        XCTAssertEqual(repository.getLogs().count, 1)
        XCTAssertEqual(repository.getLogs().first?.dayKey, "2026-09-18")
    }

    func testStoredDayIdentitySurvivesTimeZoneChange() throws {
        let database = try TestDatabaseManager()
        let losAngeles = calendar(in: "America/Los_Angeles")
        let tokyo = calendar(in: "Asia/Tokyo")
        let originalDate = try XCTUnwrap(losAngeles.date(
            from: DateComponents(year: 2026, month: 9, day: 18, hour: 23, minute: 30)
        ))
        let tokyoSeptember18 = try XCTUnwrap(tokyo.date(
            from: DateComponents(year: 2026, month: 9, day: 18, hour: 12)
        ))
        XCTAssertEqual(tokyo.component(.day, from: originalDate), 19)

        let originRepository = LogsRepo(
            databaseManager: database,
            analyticsRevisionSource: LockedRevisionSource(),
            calendar: losAngeles
        )
        XCTAssertTrue(originRepository.saveLog(DailyLog(date: originalDate, mood: 8)))

        let traveledRepository = LogsRepo(
            databaseManager: database,
            analyticsRevisionSource: LockedRevisionSource(),
            calendar: tokyo
        )
        let loaded = traveledRepository.getLogForDate(tokyoSeptember18)

        XCTAssertEqual(loaded?.dayKey, "2026-09-18")
        XCTAssertEqual(loaded?.mood, 8)
        XCTAssertEqual(loaded?.date(in: tokyo), tokyo.startOfDay(for: tokyoSeptember18))
    }

    private func calendar(in identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func insertLegacyLog(
        in db: Database,
        date: Date,
        mood: Int?,
        pain: Int?,
        notes: String?
    ) throws {
        try db.execute(sql: """
            INSERT INTO dailyLog (
                date, mood, painLevel, energyLevel, waterIntake, meals, activities,
                medicationsTaken, medicationAdherenceJSON, notes, isFlareDay,
                weather, symptomRatingsJSON
            ) VALUES (?, ?, ?, NULL, NULL, '[]', '[]', '[]', '[]', ?, 0, NULL, '[]')
            """, arguments: [date, mood, pain, notes])
    }
}

private final class LockedRevisionSource: AnalyticsRevisionProviding {
    private let lock = NSLock()
    private var revision: UInt64 = 0

    var currentRevision: UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return revision
    }

    @discardableResult
    func bump(reason: AnalyticsRevisionReason) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        revision += 1
        return revision
    }
}
