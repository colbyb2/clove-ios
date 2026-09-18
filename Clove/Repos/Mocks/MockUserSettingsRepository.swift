import Foundation

/// Mock implementation of UserSettingsRepositoryProtocol for testing and previews
final class MockUserSettingsRepository: UserSettingsRepositoryProtocol {
    /// In-memory storage of settings
    var settings: UserSettings?

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true
    var shouldReadSucceed: Bool = true

    /// Initializes with optional settings
    init(settings: UserSettings? = nil) {
        self.settings = settings ?? .default
    }

    func getSettings() -> UserSettings? {
        return settings
    }

    func loadSettings() throws -> UserSettings? {
        guard shouldSucceed && shouldReadSucceed else {
            throw RepositoryError(
                operation: .read,
                resource: "settings",
                diagnostic: "Injected mock read failure."
            )
        }
        return settings
    }

    func saveSettings(_ settings: UserSettings) -> Bool {
        if shouldSucceed {
            self.settings = settings
            return true
        }
        return false
    }
}
