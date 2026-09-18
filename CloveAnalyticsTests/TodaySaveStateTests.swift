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

    func testFailedReadKeepsLastKnownGoodDayUntilRetrySucceeds() {
        let logs = MockLogsRepository()
        logs.logs = [DailyLog(date: Date(), mood: 7)]
        let viewModel = makeViewModel(logs: logs)
        viewModel.load()

        let loadedDate = viewModel.selectedDate
        logs.shouldReadSucceed = false
        let requestedDate = Calendar.current.date(byAdding: .day, value: -2, to: loadedDate)!
        viewModel.selectedDate = requestedDate
        viewModel.loadLogData(for: requestedDate)

        XCTAssertEqual(viewModel.logData.mood, 7)
        XCTAssertTrue(Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: loadedDate))
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertTrue(viewModel.hasLoadedData)

        logs.shouldReadSucceed = true
        viewModel.retryLoad()

        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.logData.mood, 7)
    }

    func testInitialReadFailureIsNotPresentedAsSuccessfulEmptyData() {
        let logs = MockLogsRepository()
        logs.shouldReadSucceed = false
        let viewModel = makeViewModel(logs: logs)

        viewModel.load()

        XCTAssertFalse(viewModel.hasLoadedData)
        XCTAssertNotNil(viewModel.loadError)
    }

    func testInjectedWriteFailureExposesTypedErrorAndKeepsEdit() {
        let logs = MockLogsRepository()
        let viewModel = makeViewModel(logs: logs)
        viewModel.load()
        logs.shouldWriteSucceed = false

        viewModel.logData.mood = 4
        viewModel.scheduleAutoSave(for: .mood)

        XCTAssertFalse(viewModel.flushPendingChanges())
        XCTAssertEqual(viewModel.saveState, .failed)
        XCTAssertEqual(viewModel.saveError?.operation, .write)
        XCTAssertEqual(viewModel.logData.mood, 4)
    }

    private func makeViewModel(
        logs: MockLogsRepository,
        settings: UserSettings = .default,
        symptoms: MockSymptomsRepository = MockSymptomsRepository()
    ) -> TodayViewModel {
        let dependencies = MockDependencyContainer(
            logsRepository: logs,
            symptomsRepository: symptoms,
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
