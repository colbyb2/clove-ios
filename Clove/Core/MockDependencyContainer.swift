import Foundation
import SwiftUI

/// Mock dependency container for testing and previews
/// Provides configurable mock implementations of all dependencies
final class MockDependencyContainer: DependencyContaining {
    // MARK: - Repositories
    var logsRepository: LogsRepositoryProtocol
    var symptomsRepository: SymptomsRepositoryProtocol
    var settingsRepository: UserSettingsRepositoryProtocol
    var medicationRepository: MedicationRepositoryProtocol
    var bowelMovementRepository: BowelMovementRepositoryProtocol
    var searchRepository: SearchRepositoryProtocol

    // MARK: - Managers
    var toastManager: ToastManaging
    var navigationCoordinator: NavigationCoordinating
    var themeManager: ThemeManaging
    var tutorialManager: TutorialManaging
    var metricRegistry: MetricRegistryProtocol
    var timePeriodManager: TimePeriodManaging

    // MARK: - Database
    var databaseManager: DatabaseManaging

    /// Initializes a mock dependency container with optional custom implementations
    /// If a dependency is not provided, a default mock implementation is used
    init(
        logsRepository: LogsRepositoryProtocol? = nil,
        symptomsRepository: SymptomsRepositoryProtocol? = nil,
        settingsRepository: UserSettingsRepositoryProtocol? = nil,
        medicationRepository: MedicationRepositoryProtocol? = nil,
        bowelMovementRepository: BowelMovementRepositoryProtocol? = nil,
        searchRepository: SearchRepositoryProtocol? = nil,
        toastManager: ToastManaging? = nil,
        navigationCoordinator: NavigationCoordinating? = nil,
        themeManager: ThemeManaging? = nil,
        tutorialManager: TutorialManaging? = nil,
        metricRegistry: MetricRegistryProtocol? = nil,
        timePeriodManager: TimePeriodManaging? = nil,
        databaseManager: DatabaseManaging? = nil
    ) {
        self.logsRepository = logsRepository ?? MockLogsRepository()
        self.symptomsRepository = symptomsRepository ?? MockSymptomsRepository()
        self.settingsRepository = settingsRepository ?? MockUserSettingsRepository()
        self.medicationRepository = medicationRepository ?? MockMedicationRepository()
        self.bowelMovementRepository = bowelMovementRepository ?? MockBowelMovementRepository()
        self.searchRepository = searchRepository ?? MockSearchRepository()
        self.toastManager = toastManager ?? MockToastManager()
        self.navigationCoordinator = navigationCoordinator ?? MockNavigationCoordinator()
        self.themeManager = themeManager ?? MockThemeManager()
        self.tutorialManager = tutorialManager ?? MockTutorialManager()
        self.metricRegistry = metricRegistry ?? MockMetricRegistry()
        self.timePeriodManager = timePeriodManager ?? MockTimePeriodManager()
        self.databaseManager = databaseManager ?? MockDatabaseManager()
    }
}
