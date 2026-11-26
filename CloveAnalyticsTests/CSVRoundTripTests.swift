import Foundation
import GRDB
import XCTest
@testable import Clove

/// Export → import must be lossless for everything the CSV format claims to
/// carry. These tests exercise the real exporter and the real importer
/// together, so a change on either side that breaks restore is caught.
///
/// Known defects are marked with `XCTExpectFailure`. When a defect is fixed the
/// test starts "unexpectedly passing" and fails, prompting removal of the marker.
final class CSVRoundTripTests: XCTestCase {
    private let coreCategories: Set<ExportCategory> = [
        .date, .mood, .pain, .energy, .flareDay, .weather, .notes
    ]

    // MARK: - Parser

    func testParserHandlesQuotedCommasAndEscapedQuotes() throws {
        let url = try writeCSV("""
            Date,Notes,Weather
            "Mar 1, 2025","Said ""hello"", then left",Sunny
            """)

        let parsed = try CSVParser.parseCSV(from: url)

        XCTAssertEqual(parsed.headers, ["Date", "Notes", "Weather"])
        XCTAssertEqual(parsed.rows, [["Mar 1, 2025", #"Said "hello", then left"#, "Sunny"]])
        XCTAssertEqual(parsed.columnMap["Weather"], 2)
    }

    func testParserRejectsNonCSVAndEmptyFiles() throws {
        let txt = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).txt")
        try "Date\nMar 1, 2025".write(to: txt, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: txt) }
        XCTAssertThrowsError(try CSVParser.parseCSV(from: txt))

        XCTAssertThrowsError(try CSVParser.parseCSV(from: try writeCSV("   \n  ")))
        XCTAssertThrowsError(try CSVParser.parseCSV(from: try writeCSV("Date")), "Header-only files are not importable")
    }

    func testParserKeepsQuotedLineBreaksInsideOneField() throws {
        XCTExpectFailure("CSVParser splits on newlines before honoring quotes, truncating multi-line fields")
        let url = try writeCSV("Date,Notes\n\"Mar 1, 2025\",\"Line one\nLine two\"")

        let parsed = try CSVParser.parseCSV(from: url)

        XCTAssertEqual(parsed.rows.first?[1], "Line one\nLine two")
    }

    // MARK: - Export → Import

    func testExportThenImportRestoresCoreDailyFields() async throws {
        let symptom = TrackedSymptom(id: 41, name: "Joint pain")
        let first = DailyLog(
            date: day(2025, 2, 3), mood: 7, painLevel: 4, energyLevel: 5,
            notes: #"Ate out, said "never again""#, isFlareDay: true, weather: "Rainy 48°F",
            symptomRatings: [SymptomRating(symptomId: 41, symptomName: "Joint pain", rating: 6)]
        )
        let second = DailyLog(date: day(2025, 2, 4), mood: 3, energyLevel: 2)

        let restored = try await roundTrip([first, second], categories: coreCategories, symptoms: [symptom])

        XCTAssertEqual(restored.map(\.dayKey), [first.dayKey, second.dayKey])
        XCTAssertEqual(restored[0].mood, 7)
        XCTAssertEqual(restored[0].painLevel, 4)
        XCTAssertEqual(restored[0].energyLevel, 5)
        XCTAssertEqual(restored[0].notes, first.notes)
        XCTAssertEqual(restored[0].weather, "Rainy 48°F")
        XCTAssertTrue(restored[0].isFlareDay)
        XCTAssertEqual(restored[0].symptomRatings.map(\.symptomName), ["Joint pain"])
        XCTAssertEqual(restored[0].symptomRatings.map(\.rating), [6])
        XCTAssertNil(restored[1].painLevel, "Unanswered stays unanswered")
        XCTAssertFalse(restored[1].isFlareDay)
        XCTAssertTrue(restored[1].symptomRatings.isEmpty)
    }

    func testExplicitZeroRatingsSurviveRoundTrip() async throws {
        let log = DailyLog(date: day(2025, 2, 5), mood: 0, painLevel: 0, energyLevel: 0)

        let outcome = await roundTripOutcome([log], categories: coreCategories)

        try XCTExpectFailure("ImportValidator accepts 1...10 for Mood/Pain/Energy, but the app stores 0...10") {
            let restored = (try? outcome.get()) ?? []
            XCTAssertNoThrow(try outcome.get())
            XCTAssertEqual(restored.first?.painLevel, 0)
            XCTAssertEqual(restored.first?.mood, 0)
        }
    }

    func testMultiLineNotesSurviveRoundTrip() async throws {
        let log = DailyLog(date: day(2025, 2, 6), mood: 5, notes: "Morning: tired\nEvening: better")

        let restored = try await roundTrip([log], categories: coreCategories)

        XCTExpectFailure("CSVParser splits lines before honoring quotes; notes are cut at the first line break") {
            XCTAssertEqual(restored.first?.notes, "Morning: tired\nEvening: better")
        }
    }

    func testCycleCSVIsRejectedWithGuidanceInsteadOfCreatingBogusSymptoms() async throws {
        // CSV doesn't carry enough to restore cycles losslessly; the importer
        // refuses it explicitly (pointing at Full Backup) and must not
        // misread the cycle columns as symptoms.
        let log = DailyLog(date: day(2025, 2, 7), mood: 6)
        let cycle = Cycle(date: day(2025, 2, 7), flow: .medium, isStartOfCycle: true)
        let database = try TestDatabaseManager()

        let outcome = await roundTripOutcome(
            [log], categories: coreCategories.union([.cycle]), cycles: [cycle], into: database
        )

        guard case .failure(let error) = outcome, case ImportError.cycleCSV = error else {
            return XCTFail("Expected ImportError.cycleCSV, got \(outcome)")
        }
        let symptomNames = try database.read { try String.fetchAll($0, sql: "SELECT name FROM trackedSymptom") }
        XCTAssertTrue(symptomNames.isEmpty, "Created bogus symptoms: \(symptomNames)")
        XCTAssertEqual(try database.read { try DailyLog.fetchCount($0) }, 0, "Rejected import writes nothing")
    }

    // MARK: - Helpers

    private func roundTrip(
        _ logs: [DailyLog],
        categories: Set<ExportCategory>,
        symptoms: [TrackedSymptom] = [],
        cycles: [Cycle] = [],
        into database: TestDatabaseManager? = nil
    ) async throws -> [DailyLog] {
        let csv = try DataManager.shared.generateCSVContent(
            logs: logs, categories: categories, selectedSymptoms: symptoms, cycleEntries: cycles
        )
        let url = try writeCSV(csv)
        let database = try database ?? TestDatabaseManager()

        let result = try await DataImportManager(databaseManager: database).performImport(from: url)

        XCTAssertTrue(result.success)
        return try LogsRepo(databaseManager: database).loadLogs()
    }

    /// `XCTExpectFailure` does not follow a test across `await`, so tests for
    /// known defects capture the outcome first and assert synchronously.
    private func roundTripOutcome(
        _ logs: [DailyLog],
        categories: Set<ExportCategory>,
        cycles: [Cycle] = [],
        into database: TestDatabaseManager? = nil
    ) async -> Result<[DailyLog], Error> {
        do {
            return .success(try await roundTrip(logs, categories: categories, cycles: cycles, into: database))
        } catch {
            return .failure(error)
        }
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        AnalyticsTestDates.date(year, month, day, hour: 12, timeZone: .current)
    }

    private func writeCSV(_ content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).csv")
        try content.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
