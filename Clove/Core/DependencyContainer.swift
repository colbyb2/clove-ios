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
    var searchRepository: SearchRepositoryProtocol { get }

    // MARK: - Managers
    var toastManager: ToastManaging { get }
    var navigationCoordinator: NavigationCoordinating { get }
    var themeManager: ThemeManaging { get }
    var tutorialManager: TutorialManaging { get }

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

    // MARK: - Repositories (lazy-loaded)
    lazy var logsRepository: LogsRepositoryProtocol = LogsRepo.shared
    lazy var symptomsRepository: SymptomsRepositoryProtocol = SymptomsRepo.shared
    lazy var settingsRepository: UserSettingsRepositoryProtocol = UserSettingsRepo.shared
    lazy var medicationRepository: MedicationRepositoryProtocol = MedicationRepository.shared
    lazy var bowelMovementRepository: BowelMovementRepositoryProtocol = BowelMovementRepo.shared
    lazy var searchRepository: SearchRepositoryProtocol = SearchRepo.shared

    // MARK: - Managers (lazy-loaded)
    lazy var toastManager: ToastManaging = ToastManager.shared
    lazy var navigationCoordinator: NavigationCoordinating = NavigationCoordinator.shared
    lazy var themeManager: ThemeManaging = Theme.shared
    lazy var tutorialManager: TutorialManaging = TutorialManager.shared
}
