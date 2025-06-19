import Foundation
import GRDB
import SwiftUI

@Observable
class UserSettingsViewModel {
    var settings: UserSettings = .default

    func load() {
        self.settings = UserSettingsRepo.shared.getSettings() ?? .default
    }

    func save() {
        let result = UserSettingsRepo.shared.saveSettings(settings)
        if result {
            ToastManager.shared.showToast(message: "Settings saved successfully", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
        } else {
            ToastManager.shared.showToast(message: "Hmm, something went wrong.", color: CloveColors.error)
        }
    }
}
