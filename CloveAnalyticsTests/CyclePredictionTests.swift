import XCTest
@testable import Clove

final class CyclePredictionTests: XCTestCase {
    func testUnavailablePredictionExplainsMissingStartMarkers() {
        let entries = [Cycle(date: date(2026, 1, 1), flow: .medium)]
        let analysis = manager().analyze(entries: entries)

        XCTAssertNil(analysis.prediction)
        XCTAssertEqual(analysis.detectedStarts.count, 0)
        XCTAssertTrue(analysis.unavailableExplanation?.contains("none are marked as a start") == true)
    }

    func testInvalidIntervalsAreCountedAndExplained() {
        let entries = [
            Cycle(date: date(2026, 1, 1), flow: .medium, isStartOfCycle: true),
            Cycle(date: date(2026, 1, 11), flow: .medium, isStartOfCycle: true),
            Cycle(date: date(2026, 3, 2), flow: .medium, isStartOfCycle: true)
        ]
        let analysis = manager().analyze(entries: entries)

        XCTAssertNil(analysis.prediction)
        XCTAssertEqual(analysis.acceptedIntervals, [])
        XCTAssertEqual(analysis.excludedIntervals.map(\.days), [10, 50])
        XCTAssertTrue(analysis.unavailableExplanation?.contains("15–40 day range") == true)
    }

    func testExplicitEndKeepsGappedPeriodDurationIntentional() {
        let entries = [
            Cycle(date: date(2026, 1, 1), flow: .medium, isStartOfCycle: true),
            Cycle(date: date(2026, 1, 3), flow: .light, isEndOfCycle: true),
            Cycle(date: date(2026, 1, 29), flow: .medium, isStartOfCycle: true)
        ]
        let analysis = manager().analyze(entries: entries)

        XCTAssertEqual(analysis.acceptedIntervals, [28])
        XCTAssertEqual(analysis.completedPeriodDurations, [3])
        XCTAssertEqual(analysis.prediction?.length, 3)
    }

    func testGapWithoutEndMarkerIsReportedAsIncompleteInsteadOfTruncated() {
        let entries = [
            Cycle(date: date(2026, 1, 1), flow: .medium, isStartOfCycle: true),
            Cycle(date: date(2026, 1, 3), flow: .light),
            Cycle(date: date(2026, 1, 29), flow: .medium, isStartOfCycle: true)
        ]
        let analysis = manager().analyze(entries: entries)

        XCTAssertTrue(analysis.completedPeriodDurations.isEmpty)
        XCTAssertEqual(analysis.incompletePeriodCount, 2)
        XCTAssertNil(analysis.prediction?.length)
    }

    func testCalendarDayIntervalsRemainCorrectAcrossDST() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let first = calendar.date(from: DateComponents(
            year: 2026, month: 2, day: 20, hour: 12
        ))!
        let second = calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 20, hour: 12
        ))!
        let analysis = CycleManager(
            cycleRepository: MockCycleRepository(),
            calendar: calendar
        ).analyze(entries: [
            Cycle(date: first, flow: .medium, isStartOfCycle: true),
            Cycle(date: second, flow: .medium, isStartOfCycle: true)
        ])

        XCTAssertEqual(analysis.acceptedIntervals, [28])
    }

    func testExistingEntryMarkersCanBeCorrectedWithoutDeletingTheEntry() throws {
        let database = try TestDatabaseManager()
        let repository = CycleRepo(databaseManager: database)
        XCTAssertTrue(repository.save([
            Cycle(date: date(2026, 1, 1), flow: .medium)
        ]))
        var saved = try XCTUnwrap(repository.getAllCycles().first)
        saved.isStartOfCycle = true
        saved.isEndOfCycle = false

        XCTAssertTrue(repository.save([saved]))
        let corrected = repository.getAllCycles()

        XCTAssertEqual(corrected.count, 1)
        XCTAssertTrue(corrected[0].isStartOfCycle)
        XCTAssertFalse(corrected[0].isEndOfCycle == true)
    }

    private func manager() -> CycleManager {
        CycleManager(cycleRepository: MockCycleRepository(), calendar: calendar)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
