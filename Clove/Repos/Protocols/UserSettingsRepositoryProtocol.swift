import Foundation

/// Protocol defining operations for user settings management
protocol UserSettingsRepositoryProtocol: Sendable {
    /// Retrieves the user settings
    /// - Returns: The user settings if found, nil otherwise
    func getSettings() -> UserSettings?

    /// Saves user settings
    /// - Parameter settings: The settings to save
    /// - Returns: True if successful, false otherwise
    func saveSettings(_ settings: UserSettings) -> Bool
}
