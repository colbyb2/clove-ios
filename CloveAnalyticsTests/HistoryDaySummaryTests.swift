import XCTest
import GRDB
import SwiftUI
@testable import Clove

final class HistoryDaySummaryTests: XCTestCase {
    func testCurrentFoodAndActivityTablesCreateDaySummariesWithoutDailyLogs() throws {
        let database = try TestDatabaseManager()
        let foodDate = AnalyticsTestDates.date(2026, 9, 8, hour: 12)
        let activityDate = AnalyticsTestDates.date(2026, 9, 9, hour: 15)

        try database.write { db in
            var food = FoodEntry(name: "Lunch", category: .lunch, date: foodDate)
            try food.insert(db)
            var activity = ActivityEntry(name: "Walk", category: .exercise, date: activityDate)
            try activity.insert(db)
        }

        let summaries = HistoryDaySummaryRepo(databaseManager: database).getDaySummaries()
        let foodSummary = summaries[Calendar.current.startOfDay(for: foodDate)]
        let activitySummary = summaries[Calendar.current.startOfDay(for: activityDate)]

        XCTAssertNil(foodSummary?.log)
        XCTAssertEqual(foodSummary?.foodEntries.map(\.name), ["Lunch"])
        XCTAssertTrue(foodSummary?.hasMeals == true)
        XCTAssertTrue(foodSummary?.hasAnyData == true)
        XCTAssertNil(activitySummary?.log)
        XCTAssertEqual(activitySummary?.activityEntries.map(\.name), ["Walk"])
        XCTAssertTrue(activitySummary?.hasActivities == true)
        XCTAssertTrue(activitySummary?.hasAnyData == true)
    }

    @MainActor
    func testCalendarFiltersColorDaysBackedOnlyByCurrentEntryTables() {
        let foodDate = AnalyticsTestDates.date(2026, 9, 8, hour: 12)
        let activityDate = AnalyticsTestDates.date(2026, 9, 9, hour: 15)
        let summaryRepository = MockHistoryDaySummaryRepository(
            foodEntries: [FoodEntry(name: "Lunch", category: .lunch, date: foodDate)],
            activityEntries: [ActivityEntry(name: "Walk", category: .exercise, date: activityDate)]
        )
        var settings = UserSettings.default
        settings.trackMeals = true
        settings.trackActivities = true
        let viewModel = HistoryCalendarViewModel(
            daySummaryRepository: summaryRepository,
            settingsRepository: MockUserSettingsRepository(settings: settings),
            symptomsRepository: MockSymptomsRepository(),
            cycleRepository: MockCycleRepository(),
            cycleManager: MockCycleManager()
        )
        let view = HistoryCalendarView(viewModel: viewModel)
        let foodDay = Calendar.current.startOfDay(for: foodDate)
        let activityDay = Calendar.current.startOfDay(for: activityDate)

        XCTAssertTrue(viewModel.logsByDate.isEmpty)

        viewModel.selectedCategory = .meals
        XCTAssertNotEqual(view.getCalendarRecords()[foodDay]?.color, Color.clear)
        XCTAssertEqual(view.getCalendarRecords()[activityDay]?.color, Color.clear)

        viewModel.selectedCategory = .activities
        XCTAssertEqual(view.getCalendarRecords()[foodDay]?.color, Color.clear)
        XCTAssertNotEqual(view.getCalendarRecords()[activityDay]?.color, Color.clear)

        viewModel.selectedCategory = .allData
        XCTAssertNotEqual(view.getCalendarRecords()[foodDay]?.color, Color.clear)
        XCTAssertNotEqual(view.getCalendarRecords()[activityDay]?.color, Color.clear)
    }

    func testHistoryReadFailurePreservesLastKnownGoodCalendarUntilRetry() {
        let loggedDate = AnalyticsTestDates.date(2026, 9, 8, hour: 12)
        let summaryRepository = MockHistoryDaySummaryRepository(
            logs: [DailyLog(date: loggedDate, mood: 8)]
        )
        let viewModel = HistoryCalendarViewModel(
            daySummaryRepository: summaryRepository,
            settingsRepository: MockUserSettingsRepository(),
            symptomsRepository: MockSymptomsRepository(),
            cycleRepository: MockCycleRepository(),
            cycleManager: MockCycleManager()
        )
        let day = Calendar.current.startOfDay(for: loggedDate)

        XCTAssertEqual(viewModel.logsByDate[day]?.mood, 8)
        summaryRepository.summaries = [:]
        summaryRepository.shouldReadSucceed = false
        viewModel.loadData()

        XCTAssertEqual(viewModel.logsByDate[day]?.mood, 8)
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertTrue(viewModel.hasLoadedData)

        summaryRepository.shouldReadSucceed = true
        viewModel.loadData()

        XCTAssertTrue(viewModel.logsByDate.isEmpty)
        XCTAssertNil(viewModel.loadError)
    }
}
