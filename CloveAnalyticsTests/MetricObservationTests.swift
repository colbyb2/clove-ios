import XCTest
@testable import Clove

final class MetricObservationTests: XCTestCase {
    func testExistingSemanticCatalogAndObservationContracts() {
        MetricSemanticsContractChecks.assertAllPass()
        MetricCatalogContractChecks.assertAllPass()
        MetricObservationContractChecks.assertAllPass()
        MetricObservationAdapterChecks.assertAllPass()
        AnalyticsRepositoryContractChecks.assertAllPass()
    }

    func testSyntheticFixturesAreDeterministicAndCoverEdgeCases() {
        XCTAssertEqual(
            AnalyticsSyntheticFixtures.seededNoise(seed: 42, count: 20),
            AnalyticsSyntheticFixtures.seededNoise(seed: 42, count: 20)
        )
        XCTAssertNotEqual(
            AnalyticsSyntheticFixtures.seededNoise(seed: 42, count: 20),
            AnalyticsSyntheticFixtures.seededNoise(seed: 43, count: 20)
        )
        XCTAssertEqual(Set(AnalyticsSyntheticFixtures.constant(value: 5, count: 8)).count, 1)
        XCTAssertEqual(AnalyticsSyntheticFixtures.sparseDates().count, 4)
        XCTAssertEqual(AnalyticsSyntheticFixtures.duplicateCounts.reduce(0, +), 3)
        XCTAssertEqual(AnalyticsSyntheticFixtures.binaryEvents.filter { $0 }.count, 3)
        XCTAssertEqual(Set(AnalyticsSyntheticFixtures.categoricalValues).count, 3)
        XCTAssertEqual(AnalyticsSyntheticFixtures.ordinalValues.sorted(), AnalyticsSyntheticFixtures.ordinalValues)
    }

    func testDSTDayNormalizationDoesNotLoseOrDuplicateDays() {
        let zone = TimeZone(identifier: "America/New_York")!
        let normalizer = MetricDayNormalizer(timeZone: zone)
        let days = [7, 8, 9, 10].map {
            AnalyticsTestDates.date(2026, 3, $0, hour: 12, timeZone: zone)
        }
        XCTAssertEqual(Set(days.map(normalizer.dayKey)).count, 4)
    }
}
