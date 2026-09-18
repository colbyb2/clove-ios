import XCTest
@testable import Clove

@MainActor
final class TodaySaveStateTests: XCTestCase {
    func testDailyChangesAlwaysSaveAndExposeStatusEvenWhenLegacySettingIsOff() {
        let logs = MockLogsRepository()
        var settings = UserSettings.default
        settings.autoSaveEnabled = false
        settings.trackHydration = true
        let viewModel = makeViewModel(logs: logs, settings: settings)

        viewModel.load()
        viewModel.logData.mood = 8
        viewModel.logData.waterIntake = 24
        viewModel.scheduleAutoSave(for: .mood)
        viewModel.scheduleAutoSave(for: .hydration)

        XCTAssertEqual(viewModel.saveState, .saving)
        XCTAssertTrue(viewModel.flushPendingChanges())
        XCTAssertEqual(viewModel.saveState, .saved)
        XCTAssertEqual(logs.getLogForDate(viewModel.selectedDate)?.mood, 8)
        XCTAssertEqual(logs.getLogForDate(viewModel.selectedDate)?.waterIntake, 24)
    }

    func testFailedSaveKeepsEditsAndRetryPersistsThem() {
        let logs = MockLogsRepository()
        let viewModel = makeViewModel(logs: logs)
        viewModel.load()
        logs.shouldSucceed = false

        viewModel.logData.energyLevel = 3
        viewModel.scheduleAutoSave(for: .energyLevel)

        XCTAssertFalse(viewModel.flushPendingChanges())
        XCTAssertEqual(viewModel.saveState, .failed)
        XCTAssertEqual(viewModel.logData.energyLevel, 3)

        logs.shouldSucceed = true
        viewModel.retrySave()

        XCTAssertEqual(viewModel.saveState, .saved)
        XCTAssertEqual(logs.getLogForDate(viewModel.selectedDate)?.energyLevel, 3)
    }

    func testFailedFlushPreventsChangingDaysUntilRetrySucceeds() {
        let logs = MockLogsRepository()
        let viewModel = makeViewModel(logs: logs)
        viewModel.load()
        let originalDate = viewModel.selectedDate
        let requestedDate = Calendar.current.date(byAdding: .day, value: -1, to: originalDate)!
        logs.shouldSucceed = false

        viewModel.logData.mood = 6
        viewModel.scheduleAutoSave(for: .mood)
        viewModel.selectedDate = requestedDate
        viewModel.loadLogData(for: requestedDate)

        XCTAssertTrue(Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: originalDate))
        XCTAssertEqual(viewModel.logData.mood, 6)
        XCTAssertEqual(viewModel.saveState, .failed)

        logs.shouldSucceed = true
        viewModel.retrySave()
        viewModel.selectedDate = requestedDate
        viewModel.loadLogData(for: requestedDate)

        XCTAssertTrue(Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: requestedDate))
        XCTAssertEqual(logs.getLogForDate(originalDate)?.mood, 6)
    }

    private func makeViewModel(
        logs: MockLogsRepository,
        settings: UserSettings = .default
    ) -> TodayViewModel {
        let dependencies = MockDependencyContainer(
            logsRepository: logs,
            settingsRepository: MockUserSettingsRepository(settings: settings)
        )
        return TodayViewModel(
            logsRepository: dependencies.logsRepository,
            symptomsRepository: dependencies.symptomsRepository,
            settingsRepository: dependencies.settingsRepository,
            medicationRepository: dependencies.medicationRepository,
            bowelMovementRepository: dependencies.bowelMovementRepository,
            cycleRepository: dependencies.cycleRepository,
            toastManager: dependencies.toastManager
        )
    }
}
