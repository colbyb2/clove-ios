import Foundation
import SwiftUI

/// Protocol defining the contract for dependency injection containers
protocol DependencyContaining: AnyObject {
    // MARK: - Repositories
    var logsRepository: LogsRepositoryProtocol { get }
    var symptomsRepository: SymptomsRepositoryProtocol { get }
    var settingsRepository: UserSettingsRepositoryProtocol { get }
    var medicationRepository: MedicationRepositoryProtocol { get }
    var bowelMovementRepository: BowelMovementRepositoryProtocol { get }
    var foodEntryRepository: FoodEntryRepositoryProtocol { get }
    var activityEntryRepository: ActivityEntryRepositoryProtocol { get }
    var searchRepository: SearchRepositoryProtocol { get }

    // MARK: - Managers
    var toastManager: ToastManaging { get }
    var navigationCoordinator: NavigationCoordinating { get }
    var themeManager: ThemeManaging { get }
    var tutorialManager: TutorialManaging { get }
    var metricRegistry: MetricRegistryProtocol { get }
    var timePeriodManager: TimePeriodManaging { get }
    var appReviewManager: AppReviewManaging { get }

    // MARK: - Database
    var databaseManager: DatabaseManaging { get }
}

/// Production dependency container with real implementations
/// Note: Not marked as @Observable since it's a container with lazy properties
final class DependencyContainer: DependencyContaining {
    /// Shared instance for production use
    static let shared = DependencyContainer()

    /// Private initializer to enforce controlled instantiation
    private init() {}

    // MARK: - Database (initialized first as other deps depend on it)
    lazy var databaseManager: DatabaseManaging = DatabaseManager.shared

    // MARK: - Repositories (lazy-loaded with proper dependency injection)
    lazy var logsRepository: LogsRepositoryProtocol = LogsRepo(databaseManager: databaseManager)
    lazy var symptomsRepository: SymptomsRepositoryProtocol = SymptomsRepo(databaseManager: databaseManager)
    lazy var settingsRepository: UserSettingsRepositoryProtocol = UserSettingsRepo(databaseManager: databaseManager)
    lazy var medicationRepository: MedicationRepositoryProtocol = MedicationRepository(databaseManager: databaseManager)
    lazy var bowelMovementRepository: BowelMovementRepositoryProtocol = BowelMovementRepo(databaseManager: databaseManager)
    lazy var foodEntryRepository: FoodEntryRepositoryProtocol = FoodEntryRepo(databaseManager: databaseManager)
    lazy var activityEntryRepository: ActivityEntryRepositoryProtocol = ActivityEntryRepo(databaseManager: databaseManager)
    lazy var searchRepository: SearchRepositoryProtocol = SearchRepo(
        databaseManager: databaseManager,
        logsRepository: logsRepository,
        bowelMovementRepository: bowelMovementRepository
    )

    // MARK: - Managers (lazy-loaded)
    lazy var toastManager: ToastManaging = ToastManager.shared
    lazy var navigationCoordinator: NavigationCoordinating = NavigationCoordinator.shared
    lazy var themeManager: ThemeManaging = Theme.shared
    lazy var tutorialManager: TutorialManaging = TutorialManager.shared
    lazy var metricRegistry: MetricRegistryProtocol = MetricRegistry.shared
    lazy var timePeriodManager: TimePeriodManaging = TimePeriodManager.shared
    lazy var appReviewManager: AppReviewManaging = AppReviewManager.shared
}
