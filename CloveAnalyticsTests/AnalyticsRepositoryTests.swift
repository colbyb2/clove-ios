import XCTest
@testable import Clove

final class AnalyticsRepositoryTests: XCTestCase {
    func testGRDBLoaderUsesHalfOpenHistoricalRangeAndOneRead() throws {
        let database = try TestDatabaseManager()
        let start = AnalyticsTestDates.date(2023, 6, 10)
        let end = AnalyticsTestDates.date(2023, 6, 12)
        try database.write { db in
            try DailyLog(id: 1, date: start, mood: 4).insert(db)
            try DailyLog(id: 2, date: end.addingTimeInterval(-1), mood: 7).insert(db)
            try DailyLog(id: 3, date: end, mood: 10).insert(db)
        }
        let repository = DefaultAnalyticsRepository(
            sourceLoader: GRDBAnalyticsSourceLoader(databaseManager: database),
            timeZone: AnalyticsTestDates.utc
        )
        let result = try repository.load(AnalyticsRequest(
            interval: DateInterval(start: start, end: end),
            metricIDs: [MetricCatalog.mood.id]
        ))

        XCTAssertEqual(result.observations.count, 2)
        XCTAssertEqual(result.diagnostics.databaseReadCount, 1)
        XCTAssertEqual(result.diagnostics.statementCount, 9)
        XCTAssertEqual(result.coverage[MetricCatalog.mood.id]?.possibleDayCount, 2)
    }

    func testInvalidAndUnknownRequestsThrow() throws {
        let database = try TestDatabaseManager()
        let repository = DefaultAnalyticsRepository(
            sourceLoader: GRDBAnalyticsSourceLoader(databaseManager: database),
            timeZone: AnalyticsTestDates.utc
        )
        let day = AnalyticsTestDates.date(1)
        XCTAssertThrowsError(try repository.load(AnalyticsRequest(
            interval: DateInterval(start: day, duration: 0)
        )))
        XCTAssertThrowsError(try repository.load(AnalyticsRequest(
            interval: DateInterval(start: day, duration: 86_400),
            metricIDs: ["not_real"]
        )))
    }
}
