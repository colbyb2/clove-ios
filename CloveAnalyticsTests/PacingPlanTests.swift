import GRDB
import XCTest
@testable import Clove

final class PacingPlanTests: XCTestCase {
    func testPlanStatesPersistWithoutCreatingActivities() throws {
        let database = try TestDatabaseManager()
        let repo = PacingPlanRepo(databaseManager: database, calendar: AnalyticsTestDates.calendar)
        let date = AnalyticsTestDates.date(2026, 9, 22, hour: 10)

        XCTAssertTrue(repo.add(title: "  Take a short walk  ", for: date))
        var item = try XCTUnwrap(repo.visibleItems(for: date).first)
        XCTAssertEqual(item.title, "Take a short walk")
        XCTAssertEqual(item.state, .planned)

        XCTAssertTrue(repo.setState(.completed, for: item))
        item = try XCTUnwrap(repo.visibleItems(for: date).first)
        XCTAssertEqual(item.state, .completed)

        let activityCount = try database.read { try ActivityEntry.fetchCount($0) }
        XCTAssertEqual(activityCount, 0, "Completing a gentle plan must not create activity data")

        XCTAssertTrue(repo.setState(.deferred, for: item))
        XCTAssertEqual(repo.visibleItems(for: date).first?.state, .deferred)
    }

    func testRemovedPlanIsRetainedButHidden() throws {
        let database = try TestDatabaseManager()
        let repo = PacingPlanRepo(databaseManager: database, calendar: AnalyticsTestDates.calendar)
        let date = AnalyticsTestDates.date(2026, 9, 22)

        XCTAssertTrue(repo.add(title: "Reply to a message", for: date))
        let item = try XCTUnwrap(repo.visibleItems(for: date).first)
        XCTAssertTrue(repo.setState(.removed, for: item))

        XCTAssertTrue(repo.visibleItems(for: date).isEmpty)
        let stored = try database.read { try PacingPlanItem.fetchOne($0) }
        XCTAssertEqual(stored?.state, .removed)
    }

    func testUnfinishedCountExcludesCompletedAndRemovedPlans() throws {
        let database = try TestDatabaseManager()
        let repo = PacingPlanRepo(databaseManager: database, calendar: AnalyticsTestDates.calendar)
        let date = AnalyticsTestDates.date(2026, 9, 22)

        for title in ["One", "Two", "Three", "Four"] {
            XCTAssertTrue(repo.add(title: title, for: date))
        }
        let items = repo.visibleItems(for: date)
        XCTAssertTrue(repo.setState(.completed, for: items[1]))
        XCTAssertTrue(repo.setState(.deferred, for: items[2]))
        XCTAssertTrue(repo.setState(.removed, for: items[3]))

        XCTAssertEqual(repo.unfinishedCount(for: date), 2)
    }
}
