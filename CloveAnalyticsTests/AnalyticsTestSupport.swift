import Foundation
import GRDB
@testable import Clove

final class TestDatabaseManager: DatabaseManaging {
    let queue: DatabaseQueue

    init(migrations: [Migration] = Migrations.all) throws {
        queue = try DatabaseQueue()
        try migrate(migrations)
    }

    func migrate(_ migrations: [Migration]) throws {
        var migrator = DatabaseMigrator()
        for migration in migrations {
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
        try queue.write(block)
    }
}

final class TestRevisionSource: AnalyticsRevisionProviding {
    private(set) var currentRevision: UInt64 = 0
    private(set) var reasons: [AnalyticsRevisionReason] = []

    @discardableResult
    func bump(reason: AnalyticsRevisionReason) -> UInt64 {
        currentRevision += 1
        reasons.append(reason)
        return currentRevision
    }
}

final class CountingAnalyticsRepository: AnalyticsRepository {
    private let lock = NSLock()
    private(set) var loadCount = 0

    func load(_ request: AnalyticsRequest) throws -> AnalyticsDataset {
        lock.lock()
        loadCount += 1
        lock.unlock()
        return AnalyticsDataset(
            interval: request.interval,
            definitions: [],
            observations: [],
            rawEvents: [],
            coverage: [:],
            metricAliases: [:],
            diagnostics: AnalyticsQueryDiagnostics(databaseReadCount: 1, statementCount: 9)
        )
    }
}

enum AnalyticsTestDates {
    static let utc = TimeZone(secondsFromGMT: 0)!
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = utc
        return value
    }

    static func date(_ day: Int) -> Date {
        date(2025, 1, day)
    }

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        timeZone: TimeZone = utc
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}
