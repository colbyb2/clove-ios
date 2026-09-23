import XCTest
@testable import Clove

final class HydrationPreferencesTests: XCTestCase {
    func testChangingDisplayUnitDoesNotChangeCanonicalQuantity() {
        let canonicalOunces = 32

        XCTAssertEqual(HydrationUnit.fluidOunces.displayValue(fromCanonicalOunces: canonicalOunces), 32)
        XCTAssertEqual(HydrationUnit.milliliters.displayValue(fromCanonicalOunces: canonicalOunces), 946)
        XCTAssertEqual(canonicalOunces, 32)
    }

    func testMillilitersConvertToCanonicalOunces() {
        XCTAssertEqual(HydrationUnit.milliliters.canonicalOunces(fromDisplayValue: 250), 8)
        XCTAssertEqual(HydrationUnit.milliliters.canonicalOunces(fromDisplayValue: 500), 17)
    }

    func testQuickAmountsAreConfiguredIndependentlyByUnit() throws {
        let suiteName = "HydrationPreferencesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        HydrationPreferences.saveQuickAmounts([6, 10, 20], for: .fluidOunces, defaults: defaults)
        HydrationPreferences.saveQuickAmounts([200, 400, 600], for: .milliliters, defaults: defaults)

        XCTAssertEqual(HydrationPreferences.quickAmounts(for: .fluidOunces, defaults: defaults), [6, 10, 20])
        XCTAssertEqual(HydrationPreferences.quickAmounts(for: .milliliters, defaults: defaults), [200, 400, 600])
    }

    func testHydrationImportHeadersDeclareAndRecognizeUnits() throws {
        let date = Date().formatted(date: .abbreviated, time: .omitted)
        for header in ["Hydration (oz)", "Hydration (fl oz)", "Hydration (mL)"] {
            XCTAssertNoThrow(try ImportValidator.validateRowData(
                [date, "500"],
                headers: ["Date", header],
                rowNumber: 2
            ))
            XCTAssertTrue(ImportValidator.extractSymptomColumns(from: ["Date", header]).isEmpty)
        }
    }
}
