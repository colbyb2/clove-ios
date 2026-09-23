import XCTest
@testable import Clove

final class SearchRequestTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testLastSevenDaysIncludesTodayAndSixPriorCalendarDays() throws {
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 15)))
        let firstIncluded = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 17)))
        let priorDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 23)))
        let todayEvening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 23)))
        let request = SearchRequest(dateRange: .last7Days)

        XCTAssertTrue(request.includes(firstIncluded, relativeTo: reference, calendar: calendar))
        XCTAssertTrue(request.includes(todayEvening, relativeTo: reference, calendar: calendar))
        XCTAssertFalse(request.includes(priorDay, relativeTo: reference, calendar: calendar))
    }

    func testCustomRangeIsInclusiveAndNormalizesReversedDates() throws {
        let september10 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 10)))
        let september12 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 12)))
        let endOfSeptember12 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 23, minute: 59)))
        let september13 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 13)))
        let request = SearchRequest(
            dateRange: .custom,
            customStartDate: september12,
            customEndDate: september10
        )

        XCTAssertTrue(request.includes(september10, calendar: calendar))
        XCTAssertTrue(request.includes(endOfSeptember12, calendar: calendar))
        XCTAssertFalse(request.includes(september13, calendar: calendar))
    }

    func testRequestRoundTripsForFutureInterpreterBoundary() throws {
        let request = SearchRequest(
            query: "headache",
            categories: [.symptoms, .notes],
            dateRange: .last30Days,
            sortOrder: .oldestFirst
        )

        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SearchRequest.self, from: encoded)

        XCTAssertEqual(decoded, request)
    }

    func testRepositoryBoundaryHonorsCategoryDateAndSortFromOneRequest() throws {
        let oldDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))
        let recentDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 20)))
        let repository = MockSearchRepository()
        repository.mockResults = [
            result(date: recentDate, category: .symptoms, text: "Headache"),
            result(date: oldDate, category: .symptoms, text: "Headache"),
            result(date: recentDate, category: .notes, text: "Headache note")
        ]
        let request = SearchRequest(
            query: "headache",
            categories: [.symptoms],
            dateRange: .custom,
            customStartDate: oldDate,
            customEndDate: recentDate,
            sortOrder: .oldestFirst
        )

        let matches = repository.search(request: request)

        XCTAssertEqual(matches.map(\.matchedCategory), [.symptoms, .symptoms])
        XCTAssertEqual(matches.map(\.log.date), [oldDate, recentDate])
    }

    private func result(date: Date, category: SearchCategory, text: String) -> SearchResult {
        SearchResult(
            log: DailyLog(date: date),
            matchedCategory: category,
            matchedText: text,
            contextSnippet: text,
            matchRange: text.startIndex..<text.endIndex
        )
    }
}
