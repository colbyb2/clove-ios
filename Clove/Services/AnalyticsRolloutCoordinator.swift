import Foundation

enum AnalyticsMigrationState: String, Codable, Sendable {
    case pending
    case migrating
    case ready
    case failed
}

enum AnalyticsMigrationErrorCode: String, Codable, Sendable {
    case databaseUnavailable
    case migrationFailed
}

struct AnalyticsRolloutSnapshot: Equatable, Sendable {
    let state: AnalyticsMigrationState
    let attemptCount: Int
    let recoveredInterruptedAttempt: Bool
    let isUpgrade: Bool
    let errorCode: AnalyticsMigrationErrorCode?
}

@MainActor
@Observable
final class AnalyticsRolloutCoordinator {
    static let shared = AnalyticsRolloutCoordinator()

    private enum Key {
        static let state = "analyticsMigrationState.v1"
        static let attempts = "analyticsMigrationAttempts.v1"
        static let seenInstall = "analyticsRolloutSeenInstall.v1"
        static let errorCode = "analyticsMigrationErrorCode.v1"
    }

    private let defaults: UserDefaults
    private(set) var state: AnalyticsMigrationState
    private(set) var attemptCount: Int
    private(set) var recoveredInterruptedAttempt = false
    private(set) var isUpgrade: Bool
    private(set) var errorCode: AnalyticsMigrationErrorCode?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Constants.UNIFIED_ANALYTICS_ENABLED: true])
        isUpgrade = defaults.bool(forKey: Key.seenInstall)
        let stored = defaults.string(forKey: Key.state).flatMap(AnalyticsMigrationState.init(rawValue:)) ?? .pending
        let interrupted = stored == .migrating
        recoveredInterruptedAttempt = interrupted
        state = interrupted ? .pending : stored
        attemptCount = defaults.integer(forKey: Key.attempts)
        errorCode = defaults.string(forKey: Key.errorCode).flatMap(AnalyticsMigrationErrorCode.init(rawValue:))
    }

    var snapshot: AnalyticsRolloutSnapshot {
        AnalyticsRolloutSnapshot(state: state, attemptCount: attemptCount,
            recoveredInterruptedAttempt: recoveredInterruptedAttempt, isUpgrade: isUpgrade, errorCode: errorCode)
    }

    var unifiedAnalyticsEnabled: Bool {
        get { defaults.object(forKey: Constants.UNIFIED_ANALYTICS_ENABLED) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Constants.UNIFIED_ANALYTICS_ENABLED) }
    }

    @discardableResult
    func prepareDatabase(_ databaseManager: DatabaseManaging) -> Bool {
        transition(to: .migrating, error: nil)
        attemptCount += 1
        defaults.set(attemptCount, forKey: Key.attempts)
        do {
            try databaseManager.setupDatabase()
            defaults.set(true, forKey: Key.seenInstall)
            transition(to: .ready, error: nil)
            AnalyticsDiagnosticsRecorder.shared.recordLoad(.migration, outcome: .success, duration: 0)
            return true
        } catch {
            transition(to: .failed, error: .migrationFailed)
            AnalyticsDiagnosticsRecorder.shared.recordLoad(.migration, outcome: .failure, duration: 0)
            return false
        }
    }

    func retry(_ databaseManager: DatabaseManaging = DatabaseManager.shared) {
        _ = prepareDatabase(databaseManager)
    }

    private func transition(to newState: AnalyticsMigrationState, error: AnalyticsMigrationErrorCode?) {
        state = newState
        errorCode = error
        defaults.set(newState.rawValue, forKey: Key.state)
        if let error { defaults.set(error.rawValue, forKey: Key.errorCode) }
        else { defaults.removeObject(forKey: Key.errorCode) }
    }
}
