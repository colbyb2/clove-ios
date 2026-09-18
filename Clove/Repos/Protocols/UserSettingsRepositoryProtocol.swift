import Foundation

/// Protocol defining operations for user settings management
protocol UserSettingsRepositoryProtocol {
    /// A throwing read keeps database failure distinct from first-run defaults.
    func loadSettings() throws -> UserSettings?

    /// Retrieves the user settings
    /// - Returns: The user settings if found, nil otherwise
    func getSettings() -> UserSettings?

    /// Saves user settings
    /// - Parameter settings: The settings to save
    /// - Returns: True if successful, false otherwise
    func saveSettings(_ settings: UserSettings) -> Bool
}

extension UserSettingsRepositoryProtocol {
    func loadSettings() throws -> UserSettings? {
        getSettings()
    }
}
