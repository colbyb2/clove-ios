import Foundation
import XCTest
@testable import Clove

final class EventTimestampTests: XCTestCase {
    func testNewEventCombinesSelectedDayWithCurrentTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let selectedDay = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 1, day: 12, hour: 0)
        ))
        let now = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 18, hour: 16, minute: 42, second: 17)
        ))

        let eventDate = CalendarEventTime.currentTime(
            on: selectedDay,
            now: now,
            calendar: calendar
        )
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: eventDate
        )

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 12)
        XCTAssertEqual(components.hour, 16)
        XCTAssertEqual(components.minute, 42)
        XCTAssertEqual(components.second, 17)
        XCTAssertNotEqual(eventDate, calendar.startOfDay(for: selectedDay))
    }
}
