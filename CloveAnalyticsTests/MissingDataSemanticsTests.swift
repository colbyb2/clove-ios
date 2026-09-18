import XCTest
@testable import Clove

@MainActor
final class MissingDataSemanticsTests: XCTestCase {
    func testNewDayStartsUnansweredAndSaveOmitsUnansweredRatings() throws {
        let logs = MockLogsRepository()
        let symptoms = MockSymptomsRepository.withDefaultSymptoms()
        let viewModel = makeViewModel(logs: logs, symptoms: symptoms)

        viewModel.load()

        XCTAssertNil(viewModel.logData.mood)
        XCTAssertNil(viewModel.logData.painLevel)
        XCTAssertNil(viewModel.logData.energyLevel)
        XCTAssertEqual(viewModel.logData.symptomRatings.count, symptoms.symptoms.count)
        XCTAssertTrue(viewModel.logData.symptomRatings.allSatisfy { $0.ratingDouble == nil })

        viewModel.saveLog(showFeedback: false)

        let saved = try XCTUnwrap(logs.logs.first)
        XCTAssertNil(saved.mood)
        XCTAssertNil(saved.painLevel)
        XCTAssertNil(saved.energyLevel)
        XCTAssertTrue(saved.symptomRatings.isEmpty)
    }

    func testExplicitZeroAndNoPersistAsAnswers() throws {
        let logs = MockLogsRepository()
        let symptoms = MockSymptomsRepository.withDefaultSymptoms()
        let viewModel = makeViewModel(logs: logs, symptoms: symptoms)
        viewModel.load()

        viewModel.logData.mood = 0
        viewModel.logData.symptomRatings[0].ratingDouble = 0
        let binaryIndex = try XCTUnwrap(
            viewModel.logData.symptomRatings.firstIndex(where: \.isBinary)
        )
        viewModel.logData.symptomRatings[binaryIndex].ratingDouble = 0
        viewModel.saveLog(showFeedback: false)

        let saved = try XCTUnwrap(logs.logs.first)
        XCTAssertEqual(saved.mood, 0)
        XCTAssertEqual(saved.symptomRatings.count, 2)
        XCTAssertTrue(saved.symptomRatings.contains { !$0.isBinary && $0.rating == 0 })
        XCTAssertTrue(saved.symptomRatings.contains { $0.isBinary && $0.rating == 0 })
    }

    func testAnalyticsCoverageExcludesMissingButCountsExplicitZero() throws {
        let database = try TestDatabaseManager()
        let start = AnalyticsTestDates.date(2026, 9, 1)
        let secondDay = AnalyticsTestDates.date(2026, 9, 2)
        let end = AnalyticsTestDates.date(2026, 9, 3)
        try database.write { db in
            try DailyLog(id: 1, date: start, mood: nil).insert(db)
            try DailyLog(id: 2, date: secondDay, mood: 0).insert(db)
        }

        let repository = DefaultAnalyticsRepository(
            sourceLoader: GRDBAnalyticsSourceLoader(databaseManager: database),
            timeZone: AnalyticsTestDates.utc
        )
        let result = try repository.load(AnalyticsRequest(
            interval: DateInterval(start: start, end: end),
            metricIDs: [MetricCatalog.mood.id]
        ))

        let coverage = try XCTUnwrap(result.coverage[MetricCatalog.mood.id])
        XCTAssertEqual(coverage.possibleDayCount, 2)
        XCTAssertEqual(coverage.sourceDayCount, 1)
        XCTAssertEqual(coverage.observedCount, 1)
        XCTAssertEqual(coverage.missingCount, 1)
        let recordedValues = result.observations.compactMap { observation -> Double? in
            guard case .observed(let value) = observation.state else { return nil }
            return value.numericValue
        }
        XCTAssertEqual(recordedValues, [0])
    }

    private func makeViewModel(
        logs: MockLogsRepository,
        symptoms: MockSymptomsRepository
    ) -> TodayViewModel {
        var settings = UserSettings.default
        settings.trackPain = true
        return TodayViewModel(
            logsRepository: logs,
            symptomsRepository: symptoms,
            settingsRepository: MockUserSettingsRepository(settings: settings),
            medicationRepository: MockMedicationRepository(),
            bowelMovementRepository: MockBowelMovementRepository(),
            cycleRepository: MockCycleRepository(),
            toastManager: MockToastManager()
        )
    }
}
