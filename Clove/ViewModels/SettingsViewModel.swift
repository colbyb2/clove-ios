import Foundation
import GRDB
import SwiftUI

@Observable
class UserSettingsViewModel {
    // MARK: - Dependencies
    private let settingsRepository: UserSettingsRepositoryProtocol
    private let toastManager: ToastManaging

    // MARK: - State
    var settings: UserSettings = .default

    // MARK: - Initialization

    /// Convenience initializer using production singletons
    convenience init() {
        self.init(
            settingsRepository: UserSettingsRepo.shared,
            toastManager: ToastManager.shared
        )
    }

    /// Designated initializer with full dependency injection
    init(
        settingsRepository: UserSettingsRepositoryProtocol,
        toastManager: ToastManaging
    ) {
        self.settingsRepository = settingsRepository
        self.toastManager = toastManager
    }

    /// Preview factory with mock dependencies
    static func preview(settings: UserSettings = .default) -> UserSettingsViewModel {
        let container = MockDependencyContainer()
        let vm = UserSettingsViewModel(
            settingsRepository: container.settingsRepository,
            toastManager: container.toastManager
        )
        vm.settings = settings
        return vm
    }

    func load() {
        self.settings = settingsRepository.getSettings() ?? .default
    }

    func save() {
        let result = settingsRepository.saveSettings(settings)
        if result {
            toastManager.showToast(message: "Settings saved successfully", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
        } else {
            toastManager.showToast(message: "Hmm, something went wrong.", color: CloveColors.error)
        }
    }
}
