import SwiftUI

/// Predefined preview scenarios for consistent testing across the app
enum PreviewScenario {
    /// Empty state - no data, default settings
    case empty
    /// Minimal features enabled
    case minimal
    /// All features enabled
    case full
    /// With sample data for specified number of days
    case withData(days: Int)

    /// Returns a configured MockDependencyContainer for this scenario
    var container: MockDependencyContainer {
        switch self {
        case .empty:
            return MockDependencyContainer()

        case .minimal:
            return MockDependencyContainer(
                settingsRepository: MockUserSettingsRepository(settings: .minimal)
            )

        case .full:
            return MockDependencyContainer(
                settingsRepository: MockUserSettingsRepository(settings: .allEnabled)
            )

        case .withData(let days):
            return MockDependencyContainer(
                logsRepository: MockLogsRepository.withSampleData(days: days),
                symptomsRepository: MockSymptomsRepository.withDefaultSymptoms(),
                settingsRepository: MockUserSettingsRepository(settings: .allEnabled)
            )
        }
    }
}

// MARK: - UserSettings Convenience Extensions

extension UserSettings {
    /// Minimal settings with only mood tracking enabled
    static let minimal = UserSettings(
        trackMood: true,
        trackPain: false,
        trackEnergy: false,
        trackSymptoms: false,
        trackMeals: false,
        trackActivities: false,
        trackMeds: false,
        showFlareToggle: false,
        trackWeather: false,
        trackNotes: false,
        trackBowelMovements: false
    )

    /// All tracking features enabled
    static let allEnabled = UserSettings(
        trackMood: true,
        trackPain: true,
        trackEnergy: true,
        trackSymptoms: true,
        trackMeals: true,
        trackActivities: true,
        trackMeds: true,
        showFlareToggle: true,
        trackWeather: true,
        trackNotes: true,
        trackBowelMovements: true
    )
}

// MARK: - View Extension for Preview Convenience

extension View {
    /// Applies a preview scenario's mock container to this view
    func previewScenario(_ scenario: PreviewScenario) -> some View {
        self.environment(\.dependencies, scenario.container)
    }
}
