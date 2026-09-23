import XCTest
@testable import Clove

final class UserSettingsViewModelTests: XCTestCase {
    func testSilentSavePersistsWithoutShowingSuccessToast() {
        let repository = MockUserSettingsRepository(settings: .default)
        let toast = MockToastManager()
        let viewModel = UserSettingsViewModel(
            settingsRepository: repository,
            toastManager: toast
        )

        viewModel.settings.trackPain = true

        XCTAssertTrue(viewModel.save(showSuccessFeedback: false))
        XCTAssertEqual(repository.settings?.trackPain, true)
        XCTAssertEqual(toast.showCallCount, 0)
    }

    func testFailedSilentSaveReturnsFalseAndShowsFailure() {
        let repository = MockUserSettingsRepository(settings: .default)
        repository.shouldSucceed = false
        let toast = MockToastManager()
        let viewModel = UserSettingsViewModel(
            settingsRepository: repository,
            toastManager: toast
        )

        XCTAssertFalse(viewModel.save(showSuccessFeedback: false))
        XCTAssertEqual(toast.lastShownMessage, "Hmm, something went wrong.")
    }
}
