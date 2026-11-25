import XCTest
@testable import Clove

final class CSVImportCompatibilityTests: XCTestCase {
    func testCurrentExportColumnsStayCompatibleWithImporter() throws {
        let exportColumns = try DataManager.shared.generateCSVContent(logs: [], categories: Set(ExportCategory.allCases), selectedSymptoms: [])
            .components(separatedBy: "\n")[0].components(separatedBy: ",")
        let symptomName = "Joint pain"
        let headers = exportColumns + [symptomName]

        let recognized = Set(ImportValidator.expectedColumns + ["Hydration (fl oz)", "Hydration (mL)"])
        XCTAssertTrue(Set(exportColumns).isSubset(of: recognized))
        XCTAssertNoThrow(try ImportValidator.validateHeaders(headers))
        XCTAssertEqual(ImportValidator.extractSymptomColumns(from: headers), [symptomName])
        XCTAssertTrue(ImportValidator.expectedColumns.contains("Hydration (oz)"))
    }

    func testHydrationValueFromCurrentExportIsAccepted() throws {
        let headers = ["Date", "Hydration (oz)"]
        let row = [formattedDate(Date()), "64"]

        XCTAssertNoThrow(
            try ImportValidator.validateRowData(row, headers: headers, rowNumber: 2)
        )
    }

    func testInvalidHydrationValueIsRejected() {
        let headers = ["Date", "Hydration (oz)"]
        let row = [formattedDate(Date()), "not-a-number"]

        XCTAssertThrowsError(
            try ImportValidator.validateRowData(row, headers: headers, rowNumber: 2)
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
